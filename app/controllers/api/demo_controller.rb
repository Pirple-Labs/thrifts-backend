# frozen_string_literal: true

module Api
  class DemoController < Api::BaseController
    skip_before_action :authenticate_user!, only: [:personalized_feed], raise: false

    # GET /api/demo/personalized-feed
    def personalized_feed
      start_time = Time.current
      
      # Rate limiting check
      unless check_rate_limit(params[:user_id] || 1, request.remote_ip)
        return
      end
      
      # Validate required parameters
      unless validate_required_params(['user_id', 'region'])
        return
      end
      
      # Set up environment for LLM plans
      ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
      ENV['OPERATOR_TIMEOUT_MS'] = '30000'
      
      # Demo parameters with validation
      page = params[:page] || "home"
      user_id = params[:user_id]
      session_id = params[:session_id] || "demo_session_#{SecureRandom.hex(8)}"
      region = params[:region]
      pickup_only = params[:pickup_only] == "true"
      
      # Pagination parameters with proper limits
      limit = [(params[:limit] || 20).to_i, 50].min # Cap at 50 products per request
      cursor = params[:cursor]
      per_page = limit
      
      # Build snapshot using mock request and session objects
      request = OpenStruct.new(
        user_id: user_id,
        session_id: session_id,
        page: page,
        pid: params[:pid],
        region: region,
        geohash6: params[:geohash6],
        pickup_only: pickup_only
      )
      
      session = OpenStruct.new(
        id: session_id,
        user_id: user_id
      )
      
      snapshot = Personalization::SnapshotBuilder.build(request, session)

      # Build profile
      profile = Personalization::ProfileStore.slice(user_id)
      
      # Build session embedding summary
      session_embed_summary = {
        topics: ["demo", "personalized"],
        centroid_bucket: "demo-bkt-01"
      }
      
      # Get profile hash
      profile_hash = Personalization::ProfileHasher.hash(snapshot, profile)
      
      # Check for intent drift
      intent_drift = Personalization::IntentEngine.drift?(snapshot, snapshot, profile)
      
      # Try to get plan from cache (unless force_fresh is requested)
      force_fresh = params[:force_fresh] == "true"
      plan = force_fresh ? nil : Personalization::PlanCache.get(page, profile_hash)
      
      unless plan
        # Fetch plan from Operator (will fallback to control plan if Operator unavailable)
        constraints = {
          p95_budget_ms: 1000,
          max_sections: 6
        }
        
        plan = Personalization::PlannerClient.fetch_plan(
          page: page,
          snapshot: snapshot,
          profile: profile,
          session_embed_summary: session_embed_summary,
          constraints: constraints
        )
        
        Rails.logger.info("Plan received: #{plan.inspect}")
        
        # Validate plan
        if plan.nil?
          Rails.logger.error("Plan is nil, falling back to control plan")
          plan = Personalization::PlannerClient.control_plan(page)
        else
          validation_errors = Personalization::SectionValidator.validate_plan(plan, page)
          if validation_errors.any?
            Rails.logger.error("Plan validation failed: #{validation_errors.join(', ')}")
            plan = Personalization::PlannerClient.control_plan(page)
          end
        end
        
        # Store plan in cache
        Personalization::PlanCache.set(page, profile_hash, plan, ttl: plan[:ttl_seconds] || 172800)
      end

      # Execute plan sections with pagination
      sections = execute_plan_sections(plan, snapshot, profile, session_embed_summary, cursor, per_page)
      
      # Create demo feed
      feed = create_demo_feed(snapshot, plan, profile_hash)
      
      # Build pagination info
      pagination = build_pagination_info(sections, cursor, per_page)
      
      # Build response in frontend-required format
      response = {
        demo_info: {
          page: page,
          user_id: user_id,
          session_id: session_id,
          region: region,
          pickup_only: pickup_only,
          profile_hash: profile_hash,
          intent_drift: intent_drift,
          plan_source: plan[:source] || plan["source"],
          plan_id: plan[:plan_id] || plan["plan_id"]
        },
        sections: build_sections_response(sections),
        pagination: pagination,
        feed: {
          feed_id: feed.feed_uid,
          plan_id: plan[:plan_id] || plan["plan_id"],
          ttl_seconds: plan[:ttl_seconds] || plan["ttl_seconds"] || 172800,
          total_products: sections.sum { |s| s[:products].count },
          total_sections: sections.count
        },
        profile_analysis: {
          price_band: profile[:price_band],
          top_categories: profile[:top_categories],
          brand_preferences: profile[:brand_top],
          shop_preferences: profile[:shop_top],
          freshness_preference: profile[:freshness_pref],
          diversity_preference: profile[:diversity_pref]
        },
        snapshot_analysis: {
          region: snapshot[:region],
          pickup_only: snapshot[:pickup_only],
          recent_views: snapshot[:views_10m]&.count || 0,
          recent_cart_activity: snapshot[:recent_add_to_cart],
          activity_level: snapshot[:inactivity_bucket],
          last_search: snapshot[:last_search]
        }
      }
      
      # Add caching headers and performance tracking
      add_cache_headers(self, 'lite_data', 5.minutes, 60.minutes)
      track_performance('personalized_feed', start_time, response.to_json.bytesize)
      
      render json: response, status: :ok
      
    rescue => e
      Rails.logger.error("Demo personalized feed error: #{e.message}")
      render_error(
        'internal_server_error',
        'Failed to load personalized feed',
        { error: e.message },
        :internal_server_error
      )
    end

    # GET /api/demo/text-search
    def text_search
      query = params[:query]&.strip
      user_id = params[:user_id]&.to_i || 1
      region = params[:region] || "ke"
      coordination = params[:coordination] != "false"
      
      if query.blank?
        render json: { error: "Query parameter is required" }, status: :bad_request
        return
      end

      # Build snapshot for search context
      request = OpenStruct.new(
        user_id: user_id,
        session_id: "search_#{SecureRandom.hex(8)}",
        page: "search",
        region: region,
        pickup_only: params[:pickup_only] == "true"
      )
      
      session = OpenStruct.new(id: request.session_id, user_id: user_id)
      snapshot = Personalization::SnapshotBuilder.build(request, session)
      profile = Personalization::ProfileStore.slice(user_id)
      
      # Build search filters
      filters = {
        search_term: query,
        categories: params[:category] ? [params[:category]] : [],
        price_band: params[:price_band] || profile[:price_band],
        fresh_days: params[:fresh_days]&.to_i
      }.compact
      
      # Perform text search
      search_results = Personalization::SearchTextRetriever.new(
        query: query,
        filters: filters,
        limit: params[:limit]&.to_i || 50
      ).search
      
      # Apply guardrails
      guardrails_result = Personalization::Guardrails.apply(
        search_results.map { |r| { id: r[:id], score: r[:score] || 1.0 } },
        { snapshot: snapshot, profile: profile, merchant_counts: {} }
      )
      
      # Apply coordination if enabled
      if coordination
        coordinated_items = Personalization::Coordination.fill_if_applicable(
          guardrails_result[:filtered],
          { id: "search_results", count: 20 },
          snapshot,
          profile
        )
      else
        coordinated_items = guardrails_result[:filtered]
      end
      
        # Build response in frontend-required format
        response = {
          demo_info: {
            page: "search",
            user_id: user_id,
            region: region,
            search_type: "text",
            query: query,
            coordination_enabled: coordination
          },
          sections: {
            "search_results" => {
              id: "search_results",
              title: "Search Results for \"#{query}\"",
              products: coordinated_items.map { |item| item[:id].to_s },
              count: coordinated_items.count,
              reason: "Matching your search",
              layout: "grid"
            }
          },
          search_results: {
            query: query,
            total_results: coordinated_items.count,
            products: build_products_with_coordination_metadata(coordinated_items),
            filters_applied: filters,
            guardrail_drops: guardrails_result[:drop_reasons]
          }
        }
      
      render json: response, status: :ok
      
    rescue => e
      Rails.logger.error("Text search error: #{e.message}")
      render json: { 
        error: "Text search failed", 
        message: e.message,
        backtrace: Rails.env.development? ? e.backtrace.first(5) : nil
      }, status: :internal_server_error
    end

    # POST /api/demo/image-search
    def image_search
      user_id = params[:user_id]&.to_i || 1
      region = params[:region] || "ke"
      coordination = params[:coordination] != "false"
      similarity_threshold = params[:similarity_threshold]&.to_f || 0.7
      
      image_file = params[:image]
      if image_file.blank?
        render json: { error: "Image file is required" }, status: :bad_request
        return
      end
      
      # Validate image file
      unless image_file.content_type&.start_with?("image/")
        render json: { error: "Invalid file type. Please upload an image." }, status: :bad_request
        return
      end
      
      # Build snapshot for search context
      request = OpenStruct.new(
        user_id: user_id,
        session_id: "image_search_#{SecureRandom.hex(8)}",
        page: "search",
        region: region,
        pickup_only: params[:pickup_only] == "true"
      )
      
      session = OpenStruct.new(id: request.session_id, user_id: user_id)
      snapshot = Personalization::SnapshotBuilder.build(request, session)
      profile = Personalization::ProfileStore.slice(user_id)
      
      # Process image search
      begin
        # Use ImageUploadProcessor for actual image processing
        image_results = Personalization::ImageUploadProcessor.process_uploaded_image(
          image_file,
          user_id: user_id,
          region: region,
          similarity_threshold: similarity_threshold
        )
        
        # Apply guardrails
        guardrails_result = Personalization::Guardrails.apply(
          image_results,
          { snapshot: snapshot, profile: profile, merchant_counts: {} }
        )
        
        # Apply coordination if enabled
        if coordination
          coordinated_items = Personalization::Coordination.fill_if_applicable(
            guardrails_result[:filtered],
            { id: "image_similar_products", count: 20 },
            snapshot,
            profile
          )
        else
          coordinated_items = guardrails_result[:filtered]
        end
        
        # Build response
        response = {
          demo_info: {
            page: "search",
            user_id: user_id,
            region: region,
            search_type: "image_upload",
            similarity_threshold: similarity_threshold,
            coordination_enabled: coordination
          },
          search_results: {
            total_results: coordinated_items.count,
            products: build_products_with_coordination_metadata(coordinated_items),
            guardrail_drops: guardrails_result[:drop_reasons]
          }
        }
        
        render json: response, status: :ok
        
      rescue => e
        Rails.logger.error("Image search error: #{e.message}")
        render json: { 
          error: "Image search failed", 
          message: e.message,
          backtrace: Rails.env.development? ? e.backtrace.first(5) : nil
        }, status: :internal_server_error
      end
    end

    # GET /api/demo/image-search-url
    def image_search_url
      image_url = params[:image_url]&.strip
      user_id = params[:user_id]&.to_i || 1
      region = params[:region] || "ke"
      coordination = params[:coordination] != "false"
      similarity_threshold = params[:similarity_threshold]&.to_f || 0.7
      
      if image_url.blank?
        render json: { error: "image_url parameter is required" }, status: :bad_request
        return
      end
      
      # Validate URL
      begin
        uri = URI.parse(image_url)
        unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
          raise URI::InvalidURIError
        end
      rescue URI::InvalidURIError
        render json: { error: "Invalid image URL" }, status: :bad_request
        return
      end
      
      # Build snapshot for search context
      request = OpenStruct.new(
        user_id: user_id,
        session_id: "image_url_search_#{SecureRandom.hex(8)}",
        page: "search",
        region: region,
        pickup_only: params[:pickup_only] == "true"
      )
      
      session = OpenStruct.new(id: request.session_id, user_id: user_id)
      snapshot = Personalization::SnapshotBuilder.build(request, session)
      profile = Personalization::ProfileStore.slice(user_id)
      
      # Process image URL search
      begin
        # Use existing SearchImageRetriever
        constraints = {
          "pickup_only" => params[:pickup_only] == "true",
          "region" => region
        }
        
        image_results = Personalization::SearchImageRetriever.call(
          image_url: image_url,
          constraints: constraints,
          limit: params[:limit]&.to_i || 50,
          plan_id: "image_search_#{SecureRandom.hex(8)}"
        )
        
        # Filter by similarity threshold
        filtered_results = image_results.select { |r| r[:vec_score] >= similarity_threshold }
        
        # Apply guardrails
        guardrails_result = Personalization::Guardrails.apply(
          filtered_results.map { |r| { id: r[:id], score: r[:vec_score] } },
          { snapshot: snapshot, profile: profile, merchant_counts: {} }
        )
        
        # Apply coordination if enabled
        if coordination
          coordinated_items = Personalization::Coordination.fill_if_applicable(
            guardrails_result[:filtered],
            { id: "image_similar_products", count: 20 },
            snapshot,
            profile
          )
        else
          coordinated_items = guardrails_result[:filtered]
        end
        
        # Build response
        response = {
          demo_info: {
            page: "search",
            user_id: user_id,
            region: region,
            search_type: "image_url",
            image_url: image_url,
            similarity_threshold: similarity_threshold,
            coordination_enabled: coordination
          },
          search_results: {
            total_results: coordinated_items.count,
            products: build_products_with_coordination_metadata(coordinated_items),
            guardrail_drops: guardrails_result[:drop_reasons]
          }
        }
        
        render json: response, status: :ok
        
      rescue => e
        Rails.logger.error("Image URL search error: #{e.message}")
        render json: { 
          error: "Image URL search failed", 
          message: e.message,
          backtrace: Rails.env.development? ? e.backtrace.first(5) : nil
        }, status: :internal_server_error
      end
    end

    # GET /api/demo/personalized-feed/load-more
    def load_more_section
      start_time = Time.current
      
      # Rate limiting check
      unless check_rate_limit(params[:user_id] || 1, request.remote_ip)
        return
      end
      
      # Validate required parameters
      unless validate_required_params(['section_id', 'user_id', 'region'])
        return
      end
      
      section_id = params[:section_id]
      cursor = params[:cursor]
      limit = [(params[:limit] || 10).to_i, 20].min # Cap at 20 for horizontal sections
      user_id = params[:user_id]
      region = params[:region]
      
      # Parse cursor
      cursor_data = parse_cursor(cursor) if cursor
      
      # Get the section configuration from a plan
      # For demo purposes, we'll use a simple approach
      section_config = {
        id: section_id,
        title: section_id.humanize,
        reason: "More products for you",
        count: limit
      }
      
      # Build snapshot
      request = OpenStruct.new(
        user_id: user_id,
        region: region,
        page: "home"
      )
      
      session = OpenStruct.new(
        id: "demo_session_#{SecureRandom.hex(8)}",
        user_id: user_id
      )
      
      snapshot = Personalization::SnapshotBuilder.build(request, session)
      profile = Personalization::ProfileStore.slice(user_id)
      session_embed_summary = { topics: ["demo"], centroid_bucket: "demo-bkt-01" }
      
      # Retrieve products for this section
      candidates = retrieve_section_products(section_config, snapshot, profile, session_embed_summary)
      
      # Apply guardrails
      guardrails_result = Personalization::Guardrails.apply(
        candidates, 
        {
          snapshot: snapshot,
          profile: profile,
          merchant_counts: {}
        }
      )
      
      # Apply coordination if applicable
      coordinated_items = Personalization::Coordination.fill_if_applicable(
        guardrails_result[:filtered],
        section_config,
        snapshot,
        profile
      )
      
      # Apply pagination
      paginated_products = apply_pagination_to_products(coordinated_items, cursor_data, limit, section_id)
      
      # Build response
      response = {
        demo_info: {
          section_id: section_id,
          user_id: user_id,
          region: region,
          cursor: cursor
        },
        section: {
          id: section_id,
          title: section_config[:title],
          products: build_products_with_coordination_metadata(paginated_products, lite_data: true),
          count: paginated_products.count,
          reason: section_config[:reason],
          layout: determine_section_layout(section_id)
        },
        pagination: build_section_pagination_info(paginated_products, cursor, limit, section_id)
      }
      
      # Add caching headers and performance tracking
      add_cache_headers(self, 'section_window', 5.minutes, 20.minutes)
      track_performance('load_more_section', start_time, response.to_json.bytesize)
      
      render json: response, status: :ok
      
    rescue => e
      Rails.logger.error("Load more section error: #{e.message}")
      render_error(
        'internal_server_error',
        'Failed to load more products',
        { error: e.message },
        :internal_server_error
      )
    end

    # GET /api/products/:productId
    def show_product
      start_time = Time.current
      
      # Rate limiting check
      unless check_rate_limit(params[:user_id] || 1, request.remote_ip)
        return
      end
      
      # Validate required parameters
      unless validate_required_params(['user_id', 'region'])
        return
      end
      
      product_id = params[:productId]
      user_id = params[:user_id]
      region = params[:region]
      
      # Find the product
      product = Product.find_by(id: product_id)
      unless product
        render_error(
          'product_not_found',
          'Product not found',
          { product_id: product_id },
          :not_found
        )
        return
      end
      
      # Get shop information
      shop = Shop.find_by(id: product.shop_id)
      
      # Build full product data
      product_data = {
        id: product.id.to_s,
        name: product.name,
        price: product.price,
        main_image: product.main_image,
        image: product.main_image, # fallback
        shop_id: product.shop_id,
        category_id: product.category_id,
        views: product.views || 0,
        created_at: product.created_at.iso8601,
        # Full data fields
        description: product.description,
        supplementary_images: product.supplementary_images || [],
        size_options: product.size ? [product.size] : [],
        color_options: product.color ? [product.color] : [],
        condition: "Good", # Default since not in schema
        material: product.material,
        brand: product.brand_id ? "Brand #{product.brand_id}" : "Unknown Brand",
        shipping_info: {
          free_shipping: false, # Default since not in schema
          delivery_time: "3-5 days" # Default since not in schema
        }
      }
      
      # Add store information
      if shop
        product_data[:store_logo_url] = shop.store_logo_url || "https://via.placeholder.com/40x40?text=#{shop.name&.first&.upcase}"
        product_data[:store_name] = shop.name || "Unknown Store"
        product_data[:seller_info] = {
          rating: 4.0, # Default rating since not in schema
          total_sales: 0, # Default sales since not in schema
          response_time: "24 hours" # Default response time since not in schema
        }
      else
        product_data[:store_logo_url] = "https://via.placeholder.com/40x40?text=?"
        product_data[:store_name] = "Unknown Store"
        product_data[:seller_info] = {}
      end
      
      # Get similar products and more from shop
      similar_products = get_similar_products(product, user_id, region)
      more_from_shop = get_more_from_shop(product, user_id, region)
      
      response = {
        demo_info: {
          product_id: product_id,
          user_id: user_id,
          region: region
        },
        product: product_data,
        similar_products: similar_products,
        more_from_shop: more_from_shop
      }
      
      # Add caching headers and performance tracking
      add_cache_headers(self, 'full_data', 60.minutes, 24.hours)
      track_performance('show_product', start_time, response.to_json.bytesize)
      
      render json: response, status: :ok
      
    rescue => e
      Rails.logger.error("Show product error: #{e.message}")
      render_error(
        'internal_server_error',
        'Failed to load product',
        { error: e.message },
        :internal_server_error
      )
    end

    private

    def execute_plan_sections(plan, snapshot, profile, session_embed_summary, cursor = nil, per_page = 20)
      sections = []
      merchant_counts = {}
      
      # Handle both old and new plan formats (symbol and string keys)
      plan_sections = plan[:sections] || plan['sections'] || plan.dig(:page_plans, snapshot[:page], :sections) || []
      
      # Parse cursor for pagination
      cursor_data = parse_cursor(cursor) if cursor
      
      plan_sections.each do |section_config|
        # Convert string keys to symbol keys for compatibility
        section_config = section_config.deep_symbolize_keys if section_config.is_a?(Hash)
        
        # Execute section retrieval
        candidates = retrieve_section_products(section_config, snapshot, profile, session_embed_summary)
        
        # Apply guardrails
        guardrails_result = Personalization::Guardrails.apply(
          candidates, 
          {
            snapshot: snapshot,
            profile: profile,
            merchant_counts: merchant_counts
          }
        )
        
        # Apply coordination if applicable
        coordinated_items = Personalization::Coordination.fill_if_applicable(
          guardrails_result[:filtered],
          section_config,
          snapshot,
          profile
        )
        
        # Take requested count
        final_items = coordinated_items.take(section_config[:count])
        
        # Update merchant counts
        final_items.each do |item|
          product = Product.find_by(id: item[:id])
          next unless product
          merchant_counts[product.shop_id] = (merchant_counts[product.shop_id] || 0) + 1
        end
        
        # Apply pagination to products
        paginated_products = apply_pagination_to_products(final_items, cursor_data, per_page, section_config[:id])
        
        # Build section response with coordination metadata
        section = {
          id: section_config[:id],
          title: section_config[:title] || section_config[:id].humanize,
          reason: section_config[:reason],
          products: build_products_with_coordination_metadata(paginated_products, lite_data: true),
          count: paginated_products.count,
          layout: determine_section_layout(section_config[:id]),
          pre_guard_candidates: candidates,
          guardrail_drops: guardrails_result[:drop_reasons],
          retrieval_latency: 0, # Would be measured in real implementation
          guardrails_latency: 0,
          coordination_latency: 0,
          total_latency: 0
        }

        # Add coordination-specific metadata
        if coordination_section?(section_config[:id])
          section = add_coordination_metadata(section, final_items, section_config)
        end
        
        sections << section
      end
      
      sections
    end

    def retrieve_section_products(section_config, snapshot, profile, session_embed_summary)
      # Route to appropriate retrieval strategy based on section ID
      case section_config[:id]
      when "session_picks", "search_results"
        Personalization::Retrieval::SearchFusion.run(
          section_config[:filters],
          section_config[:knobs] || {},
          {
            snapshot: snapshot,
            profile: profile,
            session_embed_summary: session_embed_summary
          }
        )
      when "lookalikes"
        Personalization::Retrieval::Lookalikes.run(
          section_config[:filters],
          section_config[:knobs] || {},
          {
            snapshot: snapshot,
            profile: profile,
            session_embed_summary: session_embed_summary
          }
        )
      when "trending_near_you", "trending_in_category"
        Personalization::Retrieval::Trending.run(
          section_config[:filters],
          section_config[:knobs] || {},
          {
            snapshot: snapshot,
            profile: profile,
            session_embed_summary: session_embed_summary
          }
        )
      when "new_in_favorites"
        Personalization::Retrieval::FavoritesRules.run(
          section_config[:filters],
          section_config[:knobs] || {},
          {
            snapshot: snapshot,
            profile: profile,
            session_embed_summary: session_embed_summary
          }
        )
      when "complete_the_look", "bundle_and_save", "use_case_completion"
        # Use coordination service for these sections
        Personalization::Coordination.fill_if_applicable(
          [], # No existing items for coordination sections
          section_config,
          snapshot,
          profile,
          session_embed_summary
        )
      else
        # Default to search fusion
        Personalization::Retrieval::SearchFusion.run(
          section_config[:filters],
          section_config[:knobs] || {},
          {
            snapshot: snapshot,
            profile: profile,
            session_embed_summary: session_embed_summary
          }
        )
      end
    end

    def build_products_with_coordination_metadata(final_items)
      # Build products with coordination metadata (roles, slots, bundle info)
      final_items.map do |item|
        product_data = Personalization::ResponseShaper.build_lite_products([item[:id].to_s]).first
        
        # Add coordination metadata if present
        if item[:role]
          product_data[:role] = item[:role]
        end
        
        if item[:bundle_slot]
          product_data[:bundle_slot] = item[:bundle_slot]
        end
        
        if item[:bundle_id]
          product_data[:bundle_id] = item[:bundle_id]
        end
        
        if item[:bundle_pricing]
          product_data[:bundle_pricing] = item[:bundle_pricing]
        end
        
        product_data
      end
    end

    def coordination_section?(section_id)
      %w[complete_the_look bundle_and_save use_case_completion].include?(section_id)
    end

    def add_coordination_metadata(section, final_items, section_config)
      case section_config[:id]
      when "bundle_and_save"
        # Add bundle metadata
        bundle_item = final_items.find { |item| item[:bundle_id] }
        if bundle_item
          section[:bundle] = {
            bundle_id: bundle_item[:bundle_id],
            discount_type: "percentage",
            discount_pct: bundle_item[:bundle_pricing][:discount_pct],
            price_before_cents: bundle_item[:bundle_pricing][:price_before_cents],
            price_after_cents: bundle_item[:bundle_pricing][:price_after_cents],
            template_id: bundle_item[:bundle_pricing][:template_id]
          }
        end
      when "use_case_completion"
        # Add use case metadata
        use_case_item = final_items.find { |item| item[:use_case] }
        if use_case_item
          section[:use_case] = use_case_item[:use_case]
        end
      end
      
      section
    end

    def create_demo_feed(snapshot, plan, profile_hash)
      Feed.create!(
        feed_uid: SecureRandom.uuid,
        user_id: snapshot[:user_id],
        session_id: snapshot[:session_id],
        page: snapshot[:page],
        plan_id: plan[:plan_id] || plan["plan_id"],
        experiment_key: "demo",
        variant: plan[:source] || plan["source"],
        intent_label: nil,
        intent_confidence: nil,
        constraints: {
          pickup_only: snapshot[:pickup_only],
          region: snapshot[:region],
          geohash6: snapshot[:geohash6]
        }.compact,
        ttl_seconds: plan[:ttl_seconds] || plan["ttl_seconds"] || 172800,
        is_cache_hit: false,
        prompt_version: "plan_dsl_v1.0-mvp",
        model_version: plan[:source] || plan["source"] || "control",
        index_version: "v1.0",
        fingerprint: profile_hash
      )
    end

    def generate_mock_image_search_results(user_id, region, similarity_threshold)
      # Generate mock results for image search testing
      # In production, this would be replaced with actual image similarity search
      
      # Get some random products from the region
      products = Product.joins(:shop)
                       .where("shops.location = ?", region)
                       .where("products.stock > 0")
                       .where("products.moderation_status = ?", "approved")
                       .limit(10)
                       .order("RANDOM()")
      
      products.map.with_index do |product, index|
        # Generate mock similarity scores above threshold
        base_score = similarity_threshold + (0.3 * (index + 1) / products.count)
        {
          id: product.id,
          score: [base_score, 1.0].min,
          similarity_score: [base_score, 1.0].min
        }
      end
    end
    
    # Helper methods for frontend requirements
    
    def parse_cursor(cursor)
      return nil unless cursor.present?
      
      begin
        decoded = Base64.decode64(cursor)
        JSON.parse(decoded).symbolize_keys
      rescue => e
        Rails.logger.warn("Invalid cursor format: #{e.message}")
        nil
      end
    end
    
    def build_cursor(section_id, last_product_id, page)
      cursor_data = {
        section_id: section_id,
        last_product_id: last_product_id,
        page: page,
        timestamp: Time.current.to_i
      }
      Base64.encode64(cursor_data.to_json).strip
    end
    
    def apply_pagination_to_products(products, cursor_data, per_page, section_id = nil)
      # Determine section-specific pagination
      section_per_page = determine_section_per_page(section_id, per_page)
      
      return products.first(section_per_page) unless cursor_data
      
      # Find the last product ID from cursor
      last_product_id = cursor_data[:last_product_id]
      return products.first(section_per_page) unless last_product_id
      
      # Find the index of the last product
      last_index = products.find_index { |p| p[:id].to_s == last_product_id.to_s }
      return products.first(section_per_page) unless last_index
      
      # Return products after the last one
      products[(last_index + 1)..(last_index + section_per_page)]
    end
    
    def determine_section_per_page(section_id, default_per_page)
      return default_per_page unless section_id
      
      layout = determine_section_layout(section_id)
      case layout
      when "horizontal"
        # Initial batch: 4-6 products, subsequent: 10
        case section_id
        when "trending_near_you", "fresh_in_favorites", "use_case_completion"
          6 # Hero strips get 6 products initially
        else
          10 # Regular horizontal strips get 10
        end
      when "grid"
        20 # Grid sections get 20 products
      else
        default_per_page
      end
    end
    
    def build_pagination_info(sections, cursor, per_page)
      total_products = sections.sum { |s| s[:products].count }
      has_more = total_products >= per_page
      
      # Build next cursor from the last product of the last section
      next_cursor = nil
      if has_more && sections.any? && sections.last[:products].any?
        last_section = sections.last
        last_product = last_section[:products].last
        next_cursor = build_cursor(last_section[:id], last_product[:id], params[:page])
      end
      
      {
        current_page: cursor ? 2 : 1, # Simplified for demo
        per_page: per_page,
        total_pages: (total_products / per_page.to_f).ceil,
        total_count: total_products,
        has_next_page: has_more,
        next_cursor: next_cursor
      }
    end
    
    def build_sections_response(sections)
      sections_response = {}
      
      sections.each do |section|
        sections_response[section[:id]] = {
          id: section[:id],
          title: section[:title],
          products: section[:products], # Return full product objects, not just IDs
          count: section[:count],
          reason: section[:reason],
          layout: section[:layout]
        }
      end
      
      sections_response
    end
    
    def determine_section_layout(section_id)
      # Define layout based on section ID as per frontend requirements
      horizontal_sections = %w[
        trending_near_you fresh_in_favorites use_case_completion
        more_from_shop complete_the_look new_in_favorites
        wishlist_adjacent from_shops_you_like
      ]
      
      grid_sections = %w[
        session_picks search_results similar_products
        shop_products top_picks_for_you
      ]
      
      if horizontal_sections.include?(section_id.to_s)
        "horizontal"
      elsif grid_sections.include?(section_id.to_s)
        "grid"
      else
        "horizontal" # default
      end
    end
    
    def build_products_with_coordination_metadata(items, lite_data: true)
      items.map.with_index do |item, index|
        product = Product.find_by(id: item[:id])
        next unless product
        
        # Get shop information
        shop = Shop.find_by(id: product.shop_id)
        
        base_data = {
          id: item[:id].to_s,
          name: product.name,
          price: product.price,
          main_image: product.main_image,
          image: product.main_image, # fallback
          shop_id: product.shop_id,
          category_id: product.category_id,
          views: product.views || 0,
          created_at: product.created_at.iso8601,
          reason: item[:reason] || "Recommended for you",
          position: index,
          section: item[:section_id] || "unknown"
        }
        
        # Add store information
        if shop
          base_data[:store_logo_url] = shop.store_logo_url || "https://via.placeholder.com/40x40?text=#{shop.name&.first&.upcase}"
          base_data[:store_name] = shop.name || "Unknown Store"
        else
          base_data[:store_logo_url] = "https://via.placeholder.com/40x40?text=?"
          base_data[:store_name] = "Unknown Store"
        end
        
        # Add full data if not lite
        unless lite_data
          base_data.merge!({
            description: product.description,
            supplementary_images: product.supplementary_images || [],
            size_options: product.size ? [product.size] : [],
            color_options: product.color ? [product.color] : [],
            condition: "Good", # Default since not in schema
            material: product.material,
            brand: product.brand_id ? "Brand #{product.brand_id}" : "Unknown Brand",
            shipping_info: {
              free_shipping: false, # Default since not in schema
              delivery_time: "3-5 days" # Default since not in schema
            },
            seller_info: shop ? {
              rating: 4.0, # Default rating since not in schema
              total_sales: 0, # Default sales since not in schema
              response_time: "24 hours" # Default response time since not in schema
            } : {},
            coordination_metadata: item[:coordination_metadata] || {}
          })
        end
        
        base_data
      end.compact
    end
    
    def build_section_pagination_info(products, cursor, limit, section_id)
      has_more = products.count >= limit
      
      # Build next cursor from the last product
      next_cursor = nil
      if has_more && products.any?
        last_product = products.last
        next_cursor = build_cursor(section_id, last_product[:id], "home")
      end
      
      {
        current_page: cursor ? 2 : 1,
        per_page: limit,
        total_pages: (products.count / limit.to_f).ceil,
        total_count: products.count,
        has_next_page: has_more,
        next_cursor: next_cursor
      }
    end
    
    def get_similar_products(product, user_id, region)
      # Get similar products based on category and price range
      similar_products = Product.joins(:shop)
                                .where(moderation_status: 'approved')
                                .where("stock > 0")
                                .where(category_id: product.category_id)
                                .where.not(id: product.id)
                                .where("price BETWEEN ? AND ?", 
                                       product.price * 0.7, product.price * 1.3)
                                .limit(6)
                                .order("RANDOM()")
      
      similar_products.map do |p|
        {
          id: p.id.to_s,
          name: p.name,
          price: p.price,
          main_image: p.main_image,
          shop_id: p.shop_id
        }
      end
    end
    
    def get_more_from_shop(product, user_id, region)
      # Get more products from the same shop
      more_products = Product.joins(:shop)
                             .where(moderation_status: 'approved')
                             .where("stock > 0")
                             .where(shop_id: product.shop_id)
                             .where.not(id: product.id)
                             .limit(6)
                             .order("RANDOM()")
      
      more_products.map do |p|
        {
          id: p.id.to_s,
          name: p.name,
          price: p.price,
          main_image: p.main_image,
          shop_id: p.shop_id
        }
      end
    end
    
    # Add caching headers based on data type
    def add_cache_headers(response, data_type, soft_ttl, hard_ttl)
      case data_type
      when 'lite_data'
        response.headers['Cache-Control'] = "public, max-age=#{soft_ttl.to_i}, s-maxage=#{hard_ttl.to_i}"
        response.headers['X-Cache-TTL'] = soft_ttl.to_i
        response.headers['X-Cache-Hard-TTL'] = hard_ttl.to_i
      when 'full_data'
        response.headers['Cache-Control'] = "public, max-age=#{soft_ttl.to_i}, s-maxage=#{hard_ttl.to_i}"
        response.headers['X-Cache-TTL'] = soft_ttl.to_i
        response.headers['X-Cache-Hard-TTL'] = hard_ttl.to_i
      when 'section_window'
        response.headers['Cache-Control'] = "public, max-age=#{soft_ttl.to_i}, s-maxage=#{hard_ttl.to_i}"
        response.headers['X-Cache-TTL'] = soft_ttl.to_i
        response.headers['X-Cache-Hard-TTL'] = hard_ttl.to_i
      end
      
      response.headers['X-Response-Time'] = "#{Time.current.to_f}s"
      response.headers['X-Data-Type'] = data_type
    end
    
    # Add performance tracking
    def track_performance(endpoint, start_time, response_size)
      duration = (Time.current - start_time) * 1000 # Convert to milliseconds
      
      Rails.logger.info("[Performance] #{endpoint}: #{duration.round(2)}ms, #{response_size} bytes")
      
      # Track metrics for monitoring
      Rails.cache.write("metrics:#{endpoint}:#{Time.current.to_i}", {
        duration_ms: duration,
        response_size: response_size,
        timestamp: Time.current
      }, expires_in: 1.hour)
    end
    
    # Standardize error responses
    def render_error(error_code, message, details = {}, status = :bad_request)
      error_response = {
        error: error_code,
        message: message,
        details: details,
        timestamp: Time.current.iso8601
      }
      
      # Add retry_after for rate limiting
      if status == :too_many_requests
        error_response[:retry_after] = 30
      end
      
      render json: error_response, status: status
    end
    
    # Validate required parameters
    def validate_required_params(required_params)
      missing_params = required_params.select { |param| params[param].blank? }
      
      if missing_params.any?
        render_error(
          'missing_parameters',
          "Missing required parameters: #{missing_params.join(', ')}",
          { missing: missing_params },
          :bad_request
        )
        return false
      end
      
      true
    end
    
    # Check rate limiting
    def check_rate_limit(user_id, ip_address)
      # Per user rate limiting
      user_key = "rate_limit:user:#{user_id}"
      user_requests = Rails.cache.read(user_key) || 0
      
      if user_requests >= 100 # 100 requests per minute
        render_error(
          'rate_limit_exceeded',
          'Too many requests. Please try again later.',
          { limit: 100, window: '1 minute' },
          :too_many_requests
        )
        return false
      end
      
      # Per IP rate limiting
      ip_key = "rate_limit:ip:#{ip_address}"
      ip_requests = Rails.cache.read(ip_key) || 0
      
      if ip_requests >= 1000 # 1000 requests per minute
        render_error(
          'rate_limit_exceeded',
          'Too many requests from this IP. Please try again later.',
          { limit: 1000, window: '1 minute' },
          :too_many_requests
        )
        return false
      end
      
      # Increment counters
      Rails.cache.write(user_key, user_requests + 1, expires_in: 1.minute)
      Rails.cache.write(ip_key, ip_requests + 1, expires_in: 1.minute)
      
      true
    end
    
    # Feature flags
    def feature_enabled?(feature_name)
      case feature_name
      when 'horizontal_scroll'
        ENV['ENABLE_HORIZONTAL_SCROLL'] != 'false'
      when 'search_coordination'
        ENV['ENABLE_SEARCH_COORDINATION'] != 'false'
      when 'pdp_recommendations'
        ENV['ENABLE_PDP_RECOMMENDATIONS'] != 'false'
      else
        true # Default to enabled
      end
    end
    
    # Get configuration values
    def get_config(key, default_value = nil)
      case key
      when 'batch_sizes'
        {
          'horizontal_hero' => 6,
          'horizontal_regular' => 10,
          'grid' => 20,
          'search' => 20
        }
      when 'ttl_settings'
        {
          'lite_data_soft' => 5.minutes,
          'lite_data_hard' => 60.minutes,
          'full_data_soft' => 60.minutes,
          'full_data_hard' => 24.hours,
          'section_window_soft' => 5.minutes,
          'section_window_hard' => 20.minutes
        }
      when 'rate_limits'
        {
          'user_per_minute' => 100,
          'ip_per_minute' => 1000,
          'burst_allowance' => 20
        }
      else
        default_value
      end
    end
  end
end
