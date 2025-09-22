# app/controllers/api/feed_controller.rb
# frozen_string_literal: true
module Api
  class FeedController < Api::BaseController
    skip_before_action :authenticate_user!, only: [:start, :next, :home_grid], raise: false

    TTL_SECONDS      = 300
    MAX_POOL         = 200
    MAX_SUPP_IMAGES  = 4
    FALLBACK_TTL_SEC = 60
    ALLOWED_PAGES    = %w[home pdp profile cart checkout].freeze

    # GET /api/feeds/dynamic/:page
    def dynamic_feed
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      page = params[:page] || "home"
      
      # Validate page parameter
      unless ALLOWED_PAGES.include?(page)
        render json: { error: "Invalid page parameter" }, status: 400
        return
      end
      
      # Build user context for AI
      user_context = build_user_context_for_ai(page)
      
      # Get AI-generated sections
      ai_response = get_ai_personalized_sections(user_context)
      
      if ai_response && ai_response[:personalized_sections]
        # Process AI sections for frontend
        processed_sections = process_ai_sections_for_frontend(
          ai_response[:personalized_sections], 
          user_context
        )
        
        # Optimize section placement
        optimized_sections = optimize_section_placement(processed_sections, page)
        
        render json: {
          page: page,
          sections: optimized_sections,
          user_insights: ai_response[:user_insights],
          metadata: {
            ai_generated: true,
            user_personalized: true,
            conversion_optimized: true,
            processing_time_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
          }
        }
      else
        # Fallback to control plan
        render json: { error: "AI service unavailable" }, status: 503
      end
    end

    # GET /api/home/grid - Home page specific endpoint with pagination support
    def home_grid
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      
      # Parse pagination parameters
      cursor = params[:cursor]
      base_limit = params[:limit]&.to_i || 20
      device_type = params[:device_type] || 'desktop'
      limit = adjust_limit_for_device(base_limit, device_type)
      include_injections = params[:include_injections] == 'true'
      feed_id = params[:feed_id] # For maintaining feed state
      
      # Build user context
      user_context = build_user_context_for_ai('home')
      
      # Check if user is cold start (no events to learn from)
      if is_cold_start_user?(user_context)
        Rails.logger.info "Cold start user detected: #{user_context[:user_id] || 'anonymous'}"
        track_cold_start_analytics(user_context)
        render_home_fallback_response
        return
      end
      
      # Handle pagination
      if cursor.present?
        # Get next page of content
        response = get_next_page_content(cursor, limit, user_context, include_injections)
      else
        # Get initial content
        response = get_initial_content(limit, user_context, include_injections, feed_id)
      end
      
      # Track analytics events
      track_home_page_analytics(response[:playbook_response], response[:processed_modules], user_context)
      
          # Add processing time to metadata
          response[:metadata][:processing_time_ms] = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
          
          # Format response according to specification
          formatted_response = format_home_grid_response(response, page)
          
          render json: formatted_response
      
    rescue => e
      Rails.logger.error "Home grid generation failed: #{e.message}"
      track_error_analytics(e, user_context)
      render_home_fallback_response
    end

    # POST /api/feed/start
    def start
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      p      = feed_params
      limit  = clamp_limit(p[:limit])

      # Validate required params and rate limit
      unless validate_required_params(['page'])
        return
      end
      unless check_rate_limit(p[:user_id] || current_user&.id, request.remote_ip)
        return
      end

      # 1) Build enhanced snapshot with behavioral data
      req_struct = OpenStruct.new(
        user_id:     p[:user_id],
        session_id:  (p[:session_id].presence || "anon_#{SecureRandom.hex(8)}"),
        page:        normalize_page(p[:page]),
        pid:         p[:pid],
        region:      p[:region],
        geohash6:    p[:geohash6],
        pickup_only: ActiveModel::Type::Boolean.new.cast(p[:pickup_only])
      )
      sess_struct = OpenStruct.new(
        id: p[:session_id],
        user_id: p[:user_id],
        last_search: p[:last_search] || extract_last_search_from_events(p[:user_id], p[:session_id])
      )
      snapshot = Personalization::SnapshotBuilder.build(req_struct, sess_struct)

      # 2) Cache reuse
      fp  = Personalization::FingerprintCache.fingerprint(snapshot: snapshot, versions: versions_hash_for_fp)
      hit = Personalization::FingerprintCache.reuse_feed(fingerprint: fp, ttl_seconds: TTL_SECONDS)

      if hit.present?
        feed    = hit[:feed]
        items   = hit[:items]
        slice   = Personalization::Paginator.slice(items: items, cursor: nil, limit: limit)
        reasons = hit[:reasons].slice(*slice[:items])
        lite    = build_lite_products(slice[:items])

        return render json: sectioned_response(
          feed: feed,
          plan_id: (hit[:plan_id] || feed.plan_id || "control_v1"),
          items: slice[:items],
          lite: lite,
          reasons: reasons,
          slice: { index: 1, cursor: slice[:cursor], has_more: slice[:has_more] },
          ttl_seconds: TTL_SECONDS,
          is_cache_hit: true
        ), status: :ok
      end

      # 3) Build profile and session data for Operator
      profile = Personalization::ProfileStore.slice(p[:user_id])
      # Guard against nils in snapshot/profile when hashing
      safe_snapshot = (snapshot || {}).with_indifferent_access
      safe_profile  = (profile || {}).with_indifferent_access
      session_embed_summary = build_session_embed_summary(safe_snapshot[:session_id] || safe_snapshot["session_id"])
      profile_hash = Personalization::ProfileHasher.hash(safe_snapshot, safe_profile)
      
      # 4) Check for intent drift
      intent_drift = Personalization::IntentEngine.drift?(snapshot, snapshot, profile)
      
      # 5) Try to get plan from cache (allow force_fresh)
      force_fresh = params[:force_fresh].to_s == "true"
      plan = force_fresh ? nil : Personalization::PlanCache.get(p[:page], profile_hash)
      
      unless plan
        # 6) Fetch plan from Operator using new contract
        constraints = {
          p95_budget_ms: 1000,
          max_sections: 6
        }
        
        plan = Personalization::PlannerClient.fetch_plan(
          page: p[:page],
          snapshot: snapshot,
          profile: profile,
          session_embed_summary: session_embed_summary,
          constraints: constraints
        )
        
        if plan.nil?
          Rails.logger.error("PlannerClient returned nil plan, falling back to control plan")
          plan = Personalization::PlannerClient.control_plan(p[:page])
        end

        # 7) Validate plan
        validation_errors = Personalization::SectionValidator.validate_plan(plan, p[:page])
        if validation_errors.any?
          Rails.logger.error("Plan validation failed: #{validation_errors.join(', ')}")
          plan = Personalization::PlannerClient.control_plan(p[:page])
        end
        
        # 8) Store plan in cache
        Personalization::PlanCache.set(p[:page], profile_hash, plan, ttl: plan[:ttl_seconds] || 172800)
      end

      # 9) Execute plan sections using new contract
      sections = execute_plan_sections(plan, safe_snapshot, safe_profile, session_embed_summary)
      
      # 10) Flatten sections into ranked items for backward compatibility
      ranked = sections.flat_map { |section| section[:products] || [] }

      # 11) Persist + cache
      trace_versions = {
        prompt_version: "plan_dsl_v1.0-mvp",
        model_version: plan[:source] || "control",
        index_version: "v1.0"
      }

      plan_id = plan[:plan_id] || "control_v1"
      
      # Get experiment data for persistence
      experiment_key = ENV['EXP_HOME_RANKER'] == 'true' ? 'home_ranker_ab_2025q3' : nil
      variant = if experiment_key.present?
                  Personalization::ExperimentAssignment.get_assignment(
                    experiment_key: experiment_key,
                    user_id: snapshot["user_id"],
                    session_id: snapshot["session_id"]
                  )&.variant
                end
      
      feed, reasons_map = Personalization::SlateWriter.persist!(
        snapshot:     safe_snapshot,
        fingerprint:  fp,
        ranked_items: ranked,
        ttl_seconds:  TTL_SECONDS,
        versions:     trace_versions,
        plan_id:      plan_id,
        experiment_key: experiment_key,
        variant: variant
      )

      # Persist feed cache with plan sections and snapshot for hydration
      plan_sections_for_cache = plan.is_a?(Hash) ? (plan[:sections] || plan.dig(:page_plans, p[:page], :sections) || []) : []
      Personalization::FingerprintCache.store!(
        fingerprint: fp,
        feed:        feed,
        items:       ranked.map { _1[:id].to_s },
        reasons:     reasons_map,
        ttl_seconds: TTL_SECONDS,
        plan_sections: plan_sections_for_cache,
        snapshot: safe_snapshot
      )

      # 7) First slice
      slice_items = ranked.map { _1[:id].to_s }
      slice       = Personalization::Paginator.slice(items: slice_items, cursor: nil, limit: limit)
      lite        = build_lite_products(slice[:items])

      # 8) Cost tracking
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      total_cpu_seconds = end_time - start_time
      
      # Track API usage and costs
      Personalization::CostMeter.track_usage!(
        plan_id: plan_id,
        endpoint: '/api/feeds/start',
        cpu_seconds: total_cpu_seconds
      )

      # Build visible sections (trending + grid) and lazy injection plan
      trending = sections.find { |s| ["trending_near_you", "trending_in_category"].include?(s[:id].to_s) }
      # Ensure trending exists; if missing, execute a single trending section
      unless trending.present?
        trg_sec = execute_plan_sections({ sections: [ { id: "trending_near_you", count: 12, filters: {}, knobs: {} } ] }, safe_snapshot, safe_profile, session_embed_summary).first
        trending = trg_sec if trg_sec
      end

      visible_sections = []
      if trending.present?
        visible_sections << {
          id: trending[:id],
          type: "horizontal",
          title: trending[:title],
          reason: trending[:reason],
          products: trending[:products],
          count: trending[:products].count,
          cursor: nil,
          has_more: false
        }
      else
        # As a last resort, build a trending-like strip using popular fallback ids
        fallback_ids = Product.where("stock > 0").where(moderation_status: "approved").order(created_at: :desc).limit(12).pluck(:id).map(&:to_s)
        visible_sections << {
          id: "trending_near_you",
          type: "horizontal",
          title: "Trending near you",
          reason: "Popular picks",
          products: build_lite_products(fallback_ids),
          count: fallback_ids.count,
          cursor: nil,
          has_more: false
        }
      end

      visible_sections << {
        id: "grid",
        type: "grid",
        title: "For you",
        reason: nil,
        products: lite,
        count: lite.count,
        cursor: slice[:cursor],
        has_more: slice[:has_more]
      }

      if p[:page] == "home"
        # Ensure and include all additional strips with products now
        def build_or_fetch_section(id, title, count)
          exist = sections.find { |s| s[:id].to_s == id }
          return exist if exist&.dig(:products).present?
          execute_plan_sections({ sections: [ { id: id, count: count, filters: {}, knobs: {} } ] }, safe_snapshot, safe_profile, session_embed_summary).first
        end

        fresh = build_or_fetch_section("fresh_in_favorites", "New in favourites", 12)
        liked_viewed = build_or_fetch_section("lookalikes_since_viewed", "Since you liked", 12) || build_or_fetch_section("lookalikes", "Since you liked", 12)
        liked_purchased = build_or_fetch_section("lookalikes_since_purchased", "Complete the look", 12) || build_or_fetch_section("lookalikes", "Complete the look", 12)

        if fresh
          visible_sections << {
            id: fresh[:id],
            type: "horizontal",
            title: fresh[:title] || "New in favourites",
            reason: fresh[:reason],
            positionAfter: 12,
            products: fresh[:products],
            count: fresh[:products].count,
            cursor: nil,
            has_more: false
          }
        end
        if liked_viewed
          visible_sections << {
            id: liked_viewed[:id],
            type: "horizontal",
            title: liked_viewed[:title] || "Since you liked",
            reason: liked_viewed[:reason],
            positionAfter: 36,
            products: liked_viewed[:products],
            count: liked_viewed[:products].count,
            cursor: nil,
            has_more: false
          }
        end
        if liked_purchased
          visible_sections << {
            id: liked_purchased[:id],
            type: "horizontal",
            title: liked_purchased[:title] || "Complete the look",
            reason: liked_purchased[:reason],
            positionAfter: 60,
            products: liked_purchased[:products],
            count: liked_purchased[:products].count,
            cursor: nil,
            has_more: false
          }
        end
      end

      resp = {
        feed_id: feed.feed_uid,
        plan_id: plan_id,
        ttl_seconds: TTL_SECONDS,
        sections: visible_sections,
        trace: trace_versions,
        is_cache_hit: false,
        intent: nil
      }

      # Add cache headers and track performance
      add_cache_headers(self, 'lite_data', 5.minutes, 60.minutes)
      track_performance('/api/feeds/start', start_time, resp.to_json.bytesize)

      render json: resp, status: :ok

    rescue => e
      Rails.logger.error("[/api/feed/start] #{e.class}: #{e.message}\n#{e.backtrace&.first(3)&.join("\n")}")
      render json: popular_fallback(snapshot: safe_snapshot, limit: limit, reason: "unknown_error"), status: :ok
    end

    # POST /api/feed/next
    def next
      feed_id = params[:feed_id].to_s
      cursor  = params[:cursor].presence
      section_id = params[:section_id].presence
      limit   = clamp_limit(params[:limit])

      # Optional lightweight rate limit on hydration/pagination
      check_rate_limit(current_user&.id, request.remote_ip)

      feed = Feed.find_by(feed_uid: feed_id)
      return render json: { error: "feed not found" }, status: :not_found unless feed

      cached = Personalization::FingerprintCache.fetch_by_feed(feed: feed)
      # Section hydration path: hydrate a specific section on demand
      if section_id
        plan_sections = (cached && cached[:plan_sections]) || []
        raw = plan_sections.find { |s| (s.is_a?(Hash) && (s[:id].to_s == section_id || s["id"].to_s == section_id)) }
        unless raw
          return render json: { sections: [{ id: section_id, products: [], cursor: nil, has_more: false }] }, status: :ok
        end

        # Build context
        snapshot = (cached && cached[:snapshot]) || {}
        profile = Personalization::ProfileStore.slice(snapshot[:user_id] || snapshot["user_id"])
        session_embed_summary = build_session_embed_summary(snapshot[:session_id] || snapshot["session_id"] || feed.session_id)

        # Normalize section config keys
        sec_cfg = raw.respond_to?(:deep_symbolize_keys) ? raw.deep_symbolize_keys : raw
        sec_cfg[:count] ||= limit

        # Execute just this section
        single_plan = { sections: [sec_cfg] }
        sections = execute_plan_sections(single_plan, snapshot.symbolize_keys, profile, session_embed_summary)
        section = sections.first || { id: section_id, products: [] }

        return render json: {
          feed_id: feed.feed_uid,
          plan_id: cached&.dig(:plan_id) || feed.plan_id || "control_v1",
          sections: [
            {
              id: section[:id],
              products: section[:products],
              cursor: nil,
              has_more: false
            }
          ],
          is_cache_hit: true
        }, status: :ok
      end

      unless cached
        items   = feed.feed_items.order(:position).pluck(:product_id).map(&:to_s)
        reasons = feed.feed_items.each_with_object({}) { |fi, h| h[fi.product_id.to_s] = (fi.reason || "") }
        Personalization::FingerprintCache.store!(
          fingerprint: feed.fingerprint,
          feed:        feed,
          items:       items,
          reasons:     reasons,
          ttl_seconds: (feed.ttl_seconds || TTL_SECONDS)
        )
        cached = { items:, reasons: }
      end

      slice = Personalization::Paginator.slice(items: cached[:items], cursor:, limit:)
      lite  = build_lite_products(slice[:items])

      render json: sectioned_response(
        feed: feed,
        plan_id: cached&.dig(:plan_id) || feed.plan_id || "control_v1",
        items: slice[:items],
        lite: lite,
        reasons: cached[:reasons].slice(*slice[:items]),
        slice: { index: slice[:index], cursor: slice[:cursor], has_more: slice[:has_more] },
        ttl_seconds: (feed.ttl_seconds || TTL_SECONDS),
        is_cache_hit: true
      ), status: :ok
    end

    private

    def clamp_limit(val)
      (val.presence || 24).to_i.clamp(1, 60)
    end
    
    # Get initial content for home grid
    def get_initial_content(limit, user_context, include_injections, feed_id)
      # Execute playbook for initial content
      playbook_response = Personalization::PlaybookExecutor.execute_for_user(
        current_user&.id,
        'home',
        user_context
      )
      
      # Check if playbook returned empty modules (fallback scenario)
      if playbook_response[:modules].blank? || playbook_response[:modules].all? { |m| m[:items].blank? }
        Rails.logger.info "Empty playbook response, using fallback for user: #{user_context[:user_id] || 'anonymous'}"
        track_fallback_analytics(playbook_response, user_context)
        return render_home_fallback_response
      end
      
      # Process modules for home page
      processed_modules = process_home_modules(playbook_response[:modules])
      
      # Extract content sections
      trending_strip = extract_trending_strip(processed_modules)
      discovery_grid = extract_discovery_grid(processed_modules)
      dynamic_injections = include_injections ? extract_dynamic_injections(processed_modules) : []
      
      # Get initial products for discovery grid
      initial_products = discovery_grid&.dig(:items) || []
      products_to_return = initial_products.first(limit)
      
      # Generate cursor for next page
      next_cursor = generate_next_cursor(processed_modules, limit, user_context)
      
      # Store feed state for pagination
      feed_state = store_feed_state(feed_id, processed_modules, user_context)
      
      {
        page: 'home',
        content: {
          products: products_to_return,
          trending_strip: trending_strip,
          dynamic_injections: dynamic_injections
        },
        pagination: {
          cursor: next_cursor,
          has_more: has_more_content?(processed_modules, limit),
          total_products: get_total_products_count(processed_modules),
          feed_id: feed_state[:feed_id]
        },
        metadata: playbook_response[:metadata],
        playbook_response: playbook_response,
        processed_modules: processed_modules
      }
    end
    
    # Get next page of content
    def get_next_page_content(cursor, limit, user_context, include_injections)
      # Decode cursor to get pagination state
      cursor_data = decode_cursor(cursor)
      return render_home_fallback_response unless cursor_data
      
      # Get stored feed state
      feed_state = get_feed_state(cursor_data[:feed_id])
      return render_home_fallback_response unless feed_state
      
      # Get next batch of products
      next_products = get_next_products_batch(feed_state, cursor_data, limit)
      
      # Get dynamic injections if requested
      dynamic_injections = []
      if include_injections
        dynamic_injections = get_dynamic_injections_for_page(cursor_data[:page], user_context)
      end
      
      # Generate next cursor
      next_cursor = generate_next_cursor(feed_state[:processed_modules], cursor_data[:page] + 1, user_context, cursor_data[:feed_id])
      
      {
        page: 'home',
        content: {
          products: next_products,
          dynamic_injections: dynamic_injections
        },
        pagination: {
          cursor: next_cursor,
          has_more: has_more_content?(feed_state[:processed_modules], cursor_data[:page] + 1),
          total_products: get_total_products_count(feed_state[:processed_modules])
        },
        metadata: {
          ai_generated: true,
          user_personalized: true,
          page: cursor_data[:page] + 1
        },
        playbook_response: feed_state[:playbook_response],
        processed_modules: feed_state[:processed_modules]
      }
    end

    def normalize_page(page)
      pg = page.to_s
      return pg if ALLOWED_PAGES.include?(pg)
      "home"
    end
    
    # Generate cursor for pagination
    def generate_next_cursor(processed_modules, page, user_context, feed_id = nil)
      cursor_data = {
        page: page,
        feed_id: feed_id,
        user_id: user_context[:user_id],
        timestamp: Time.current.to_i
      }
      
      # Encode cursor data
      Base64.urlsafe_encode64(cursor_data.to_json)
    end
    
    # Decode cursor to get pagination state
    def decode_cursor(cursor)
      return nil unless cursor.present?
      
      begin
        decoded = Base64.urlsafe_decode64(cursor)
        JSON.parse(decoded, symbolize_names: true)
      rescue => e
        Rails.logger.error "Failed to decode cursor: #{e.message}"
        nil
      end
    end
    
    # Store feed state for pagination
    def store_feed_state(feed_id, processed_modules, user_context)
      feed_id ||= SecureRandom.uuid
      
      # Store in Redis with TTL
      feed_state = {
        feed_id: feed_id,
        processed_modules: processed_modules,
        user_context: user_context,
        created_at: Time.current.to_i,
        ttl: 1.hour.to_i
      }
      
      Rails.cache.write("feed_state:#{feed_id}", feed_state, expires_in: 1.hour)
      
      feed_state
    end
    
    # Get stored feed state
    def get_feed_state(feed_id)
      return nil unless feed_id.present?
      
      Rails.cache.read("feed_state:#{feed_id}")
    end
    
    # Get next batch of products for pagination
    def get_next_products_batch(feed_state, cursor_data, limit)
      processed_modules = feed_state[:processed_modules]
      page = cursor_data[:page]
      user_context = feed_state[:user_context]
      
      # Get already served product IDs to avoid duplicates
      served_product_ids = get_served_product_ids(feed_state, page)
      
      # Generate NEW products using playbook system for this specific page
      new_products = generate_new_products_for_page(user_context, page, limit, served_product_ids)
      
      new_products
    end
    
    # Generate new products for a specific page using playbook
    def generate_new_products_for_page(user_context, page, limit, excluded_ids = [])
      # Build enhanced user context for this page
      enhanced_context = user_context.merge(
        page: 'home',
        page_number: page,
        excluded_product_ids: excluded_ids,
        content_type: 'discovery_grid'
      )
      
      # Execute playbook for this specific page
      playbook_response = Personalization::PlaybookExecutor.execute_for_user(
        user_context[:user_id],
        'home',
        enhanced_context
      )
      
      # Process modules and extract products
      processed_modules = process_home_modules(playbook_response[:modules])
      discovery_module = processed_modules.find { |m| m[:placement] == 'home_discovery' }
      
      if discovery_module && discovery_module[:items].present?
        # Return new products from playbook
        discovery_module[:items].first(limit)
      else
        # Fallback: get trending products excluding already served ones
        get_trending_products_fallback(limit, excluded_ids)
      end
    end
    
    # Get already served product IDs to avoid duplicates
    def get_served_product_ids(feed_state, current_page)
      served_ids = []
      
      # Get products from previous pages
      (1...current_page).each do |page_num|
        page_products = get_products_for_page(feed_state, page_num)
        served_ids += page_products.map { |p| p[:id] }
      end
      
      served_ids.uniq
    end
    
    # Get products for a specific page from feed state
    def get_products_for_page(feed_state, page_num)
      processed_modules = feed_state[:processed_modules]
      discovery_module = processed_modules.find { |m| m[:placement] == 'home_discovery' }
      
      return [] unless discovery_module
      
      # Calculate offset for this page (assuming 20 products per page)
      products_per_page = 20
      offset = (page_num - 1) * products_per_page
      
      all_products = discovery_module[:items] || []
      all_products[offset, products_per_page] || []
    end
    
    # Fallback method to get trending products
    def get_trending_products_fallback(limit, excluded_ids = [])
      products = Product.joins(:shop, :category)
                       .where("stock > 0")
                       .where(moderation_status: "approved")
                       .where.not(id: excluded_ids)
                       .order(views: :desc, created_at: :desc)
                       .limit(limit)
      
      build_lite_products(products.pluck(:id))
    end
    
    # Get dynamic injections for specific page using AI playbook
    def get_dynamic_injections_for_page(page, user_context)
      # Use AI playbook to determine dynamic injections for this page
      enhanced_context = user_context.merge(
        page: 'home',
        page_number: page,
        content_type: 'dynamic_injections'
      )
      
      # Execute playbook for dynamic injections
      playbook_response = Personalization::PlaybookExecutor.execute_for_user(
        user_context[:user_id],
        'home',
        enhanced_context
      )
      
      # Process modules and extract dynamic injection modules
      processed_modules = process_home_modules(playbook_response[:modules])
      injection_modules = processed_modules.select { |m| m[:placement]&.include?('injection') }
      
      if injection_modules.any?
        # Return AI-determined injections
        injection_modules.map do |module_data|
          {
            id: module_data[:id] || "ai_injection_#{page}",
            title: module_data[:title] || "AI Recommended",
            type: 'horizontal',
            items: module_data[:items] || [],
            placement: module_data[:placement],
            metadata: {
              ai_generated: true,
              page: page,
              generated_at: Time.current.to_i,
              module_type: module_data[:type]
            }
          }
        end
      else
        # Fallback: Get basic trending injections if AI doesn't provide any
        get_fallback_injections(page, user_context)
      end
    end
    
    # Get trending category injections for first page
    def get_trending_category_injections(user_context)
      trending_categories = get_trending_categories
      
      trending_categories.map do |category|
        products = get_category_products(category[:name], limit: 8)
        next if products.empty?
        
        {
          id: "trending_#{category[:name]}_strip",
          title: "Trending in #{category[:name].humanize}",
          type: 'horizontal',
          items: products,
          placement: "trending_injection",
          metadata: {
            category: category[:name],
            trending: true,
            page: 1,
            generated_at: Time.current.to_i
          }
        }
      end.compact
    end
    
    # Get personalized injections based on user behavior
    def get_personalized_injections(user_context)
      # Get user's preferred categories from behavior
      preferred_categories = get_user_preferred_categories(user_context)
      
      preferred_categories.map do |category|
        products = get_category_products(category, limit: 8)
        next if products.empty?
        
        {
          id: "personalized_#{category}_strip",
          title: "Recommended #{category.humanize}",
          type: 'horizontal',
          items: products,
          placement: "personalized_injection",
          metadata: {
            category: category,
            personalized: true,
            page: 2,
            generated_at: Time.current.to_i
          }
        }
      end.compact
    end
    
    # Get discovery injections for exploration
    def get_discovery_injections(user_context)
      discovery_categories = get_discovery_categories(user_context)
      
      discovery_categories.map do |category|
        products = get_category_products(category, limit: 8)
        next if products.empty?
        
        {
          id: "discovery_#{category}_strip",
          title: "Discover #{category.humanize}",
          type: 'horizontal',
          items: products,
          placement: "discovery_injection",
          metadata: {
            category: category,
            discovery: true,
            page: 3,
            generated_at: Time.current.to_i
          }
        }
      end.compact
    end
    
    # Get rotating category injections for subsequent pages
    def get_rotating_category_injections(page, user_context)
      # Rotate through different categories
      categories = ['fashion', 'beauty', 'electronics', 'home', 'sports', 'books', 'toys', 'jewelry']
      category = categories[(page - 1) % categories.length]
      
      products = get_category_products(category, limit: 8)
      return [] if products.empty?
      
      [{
        id: "rotating_#{category}_strip_#{page}",
        title: "#{category.humanize} Collection",
        type: 'horizontal',
        items: products,
        placement: "rotating_injection_#{page}",
        metadata: {
          category: category,
          rotating: true,
          page: page,
          generated_at: Time.current.to_i
        }
      }]
    end
    
    # Get trending categories based on recent activity
    def get_trending_categories
      # Get categories with most views in last 7 days
      Category.joins(:products)
              .where(products: { created_at: 7.days.ago..Time.current })
              .group('categories.id, categories.name')
              .order('SUM(products.views) DESC')
              .limit(3)
              .pluck(:name)
              .map { |name| { name: name, trending: true } }
    end
    
    # Get user's preferred categories from behavior
    def get_user_preferred_categories(user_context)
      return [] unless user_context[:user_id]
      
      # Get categories from user's recent interactions
      Event.where(user_id: user_context[:user_id])
           .where(event_name: ['product_impression', 'product_click'])
           .where('timestamp_utc >= ?', 30.days.ago)
           .joins('JOIN products ON products.id = CAST(events.payload->>\'product_id\' AS INTEGER)')
           .joins('JOIN categories ON categories.id = products.category_id')
           .group('categories.name')
           .order('COUNT(*) DESC')
           .limit(3)
           .pluck('categories.name')
    end
    
    # Get discovery categories (categories user hasn't explored much)
    def get_discovery_categories(user_context)
      return [] unless user_context[:user_id]
      
      # Get categories with low user interaction
      user_categories = get_user_preferred_categories(user_context)
      
      Category.where.not(name: user_categories)
              .joins(:products)
              .where(products: { stock: 1..Float::INFINITY, moderation_status: 'approved' })
              .group('categories.id, categories.name')
              .order('COUNT(products.id) DESC')
              .limit(3)
              .pluck(:name)
    end
    
    # Get products for specific category
    def get_category_products(category, limit: 8)
      # Find category by name
      category_record = Category.find_by('name ILIKE ?', "%#{category}%")
      return [] unless category_record
      
      # Get products from this category
      products = Product.joins(:shop, :brand, :category)
                       .where(category_id: category_record.id)
                       .where("stock > 0")
                       .where(moderation_status: "approved")
                       .order(created_at: :desc)
                       .limit(limit)
      
      build_lite_products(products.pluck(:id))
    end
    
    # Check if there's more content available
    def has_more_content?(processed_modules, page)
      # Get total products from all modules
      total_products = get_total_products_count(processed_modules)
      
      # Assume 20 products per page
      products_per_page = 20
      max_pages = (total_products / products_per_page.to_f).ceil
      
      page < max_pages
    end
    
    # Get total products count from processed modules
    def get_total_products_count(processed_modules)
      processed_modules.sum do |module_data|
        (module_data[:items] || []).length
      end
    end
    
    # Adjust limit based on device type
    def adjust_limit_for_device(base_limit, device_type)
      case device_type
      when 'mobile'
        [base_limit, 12].min  # Fewer products on mobile
      when 'tablet'
        [base_limit, 20].min  # Medium amount on tablet
      else
        [base_limit, 50].min  # Full amount on desktop (capped at 50)
      end
    end

    def feed_params
      # Allow top-level keys, alias :session -> :session_id, and optionally flatten nested :feed
      allowed = [:page, :pid, :session_id, :user_id, :anonymous_id, :region, :geohash6, :pickup_only, :limit, :session, :cursor, :feed_id, :include_injections, :device_type]
      permitted = params.permit(*allowed, feed: allowed)

      # Start with top-level allowed keys only (excluding :session alias for now)
      top = permitted.slice(:page, :pid, :session_id, :user_id, :anonymous_id, :region, :geohash6, :pickup_only, :limit, :cursor, :feed_id, :include_injections, :device_type).to_h

      # Apply alias for session -> session_id (top-level first)
      top[:session_id] = top[:session_id].presence || permitted[:session].presence

      # If nested :feed is present, merge allowed keys (do not overwrite existing non-blank)
      if permitted[:feed].present?
        feed_sub = permitted[:feed]
        # Merge feed keys
        [:page, :pid, :session_id, :user_id, :anonymous_id, :region, :geohash6, :pickup_only, :limit].each do |k|
          val = feed_sub[k]
          top[k] = val if val.present? && top[k].blank?
        end
        # Apply alias inside feed: feed[:session] -> session_id
        top[:session_id] = top[:session_id].presence || feed_sub[:session].presence
      end

      top.with_indifferent_access
    end

    def versions_hash_for_fp
      { 
        prompt_version: "qp_contract_v2", 
        model_version: "ai_contract_v2", 
        index_version: "vec_contract_v2",
        snapshot_builder: "2.0" # Enhanced with behavioral data
      }
    end

    def extract_last_search_from_events(user_id, session_id)
      # Extract last search term from recent events
      last_search_event = Event.where(
        user_id: user_id,
        session_id: session_id,
        event_name: "search",
        timestamp_utc: 1.hour.ago..
      ).order(:timestamp_utc).last
      
      last_search_event&.payload&.dig("search_term") || last_search_event&.payload&.dig(:search_term)
    end

    def process_ai_personalized_section(section_config:, snapshot:, profile:, session_embed_summary:, position:)
      # Extract AI-generated section data
      section_id = section_config[:id] || section_config["id"]
      section_title = section_config[:title] || section_config["title"]
      section_type = section_config[:type] || section_config["type"]
      conversion_potential = section_config[:conversion_potential] || section_config["conversion_potential"]
      placement_suggestions = section_config[:placement_suggestions] || section_config["placement_suggestions"] || []
      search_strategy = section_config[:search_strategy] || section_config["search_strategy"] || {}
      
      # Execute retrieval with AI search strategy
      retrieval_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      products = execute_ai_search_strategy(search_strategy, snapshot, profile, session_embed_summary)
      retrieval_time = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - retrieval_start) * 1000
      
      # Build dynamic section response
      {
        id: section_id,
        title: section_title,
        type: section_type,
        layout: determine_section_layout(section_type),
        conversion_potential: conversion_potential,
        placement_suggestions: placement_suggestions,
        products: products,
        metadata: {
          ai_generated: true,
          search_strategy: search_strategy,
          retrieval_time_ms: retrieval_time.round(2),
          product_count: products.count,
          position: position,
          user_insights: extract_user_insights_from_section(section_config)
        }
      }
    end

    def process_ai_section(section_id:, section_title:, section_type:, section_config:, snapshot:, profile:, session_embed_summary:, position:)
      # Extract filters and knobs from AI-generated section
      filters = section_config[:filters] || section_config["filters"] || {}
      knobs = section_config[:knobs] || section_config["knobs"] || {}
      
      # Apply AI-generated search strategy
      search_strategy = build_search_strategy(
        section_type: section_type,
        filters: filters,
        knobs: knobs,
        snapshot: snapshot,
        profile: profile
      )
      
      # Execute retrieval with AI strategy
      retrieval_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      products = execute_retrieval_strategy(search_strategy, snapshot, profile, session_embed_summary)
      retrieval_time = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - retrieval_start) * 1000
      
      # Build section response
      {
        id: section_id,
        title: section_title,
        type: section_type,
        layout: determine_section_layout(section_type),
        products: products,
        metadata: {
          ai_generated: true,
          search_strategy: search_strategy,
          retrieval_time_ms: retrieval_time.round(2),
          product_count: products.count,
          position: position
        }
      }
    end

    def build_search_strategy(section_type:, filters:, knobs:, snapshot:, profile:)
      # Build search strategy based on AI-generated section type and filters
      base_strategy = {
        algorithm: knobs[:algorithm] || knobs["algorithm"] || "default",
        limit: knobs[:limit] || knobs["limit"] || 20,
        filters: filters.dup
      }
      
      # Apply section-specific logic
      case section_type
      when "trending"
        base_strategy[:algorithm] = "trending"
        base_strategy[:filters][:region] = snapshot[:region]
        base_strategy[:filters][:time_window] = "7d"
        
      when "similar"
        base_strategy[:algorithm] = "similarity"
        if snapshot[:pid]
          base_strategy[:filters][:reference_product_id] = snapshot[:pid]
        end
        
      when "complementary"
        base_strategy[:algorithm] = "complementary"
        if snapshot[:pid]
          base_strategy[:filters][:reference_product_id] = snapshot[:pid]
        end
        
      when "discovery"
        base_strategy[:algorithm] = "diversity"
        base_strategy[:filters][:diversity_boost] = true
        
      when "completion"
        base_strategy[:algorithm] = "completion"
        # Use behavioral patterns for completion logic
        if snapshot[:behavioral_patterns]&.dig(:search_to_browse)
          base_strategy[:filters][:completion_type] = "search_completion"
        end
      end
      
      # Apply user profile preferences
      if profile[:price_band]
        base_strategy[:filters][:price_band] = profile[:price_band]
      end
      
      if profile[:top_categories]&.any?
        base_strategy[:filters][:preferred_categories] = profile[:top_categories]
      end
      
      base_strategy
    end

    def determine_section_layout(section_type)
      # Determine layout based on section type
      case section_type
      when "trending", "completion"
        "horizontal"
      when "similar", "complementary", "discovery", "personalized"
        "grid"
      else
        "grid"
      end
    end

    def execute_ai_search_strategy(search_strategy, snapshot, profile, session_embed_summary)
      # Execute product retrieval based on AI-generated search strategy
      algorithm = search_strategy[:algorithm] || search_strategy["algorithm"]
      filters = search_strategy[:filters] || search_strategy["filters"] || {}
      keywords = search_strategy[:keywords] || search_strategy["keywords"] || []
      time_window = search_strategy[:time_window] || search_strategy["time_window"]
      
      # Convert AI filters to Rails-compatible format
      rails_filters = convert_ai_filters_to_rails(filters, keywords)
      
      case algorithm
      when "trending"
        execute_trending_retrieval(rails_filters, 20, snapshot)
      when "similarity"
        execute_similarity_retrieval(rails_filters, 20, snapshot)
      when "complementary"
        execute_complementary_retrieval(rails_filters, 20, snapshot)
      when "diversity"
        execute_diversity_retrieval(rails_filters, 20, snapshot, profile)
      when "completion"
        execute_completion_retrieval(rails_filters, 20, snapshot, profile)
      else
        execute_default_retrieval(rails_filters, 20, snapshot, profile)
      end
    end

    def convert_ai_filters_to_rails(ai_filters, keywords)
      # Convert AI filter format to Rails-compatible format
      rails_filters = {}
      
      # Handle brand and category names (convert to IDs if needed)
      if ai_filters[:brand] || ai_filters["brand"]
        brand_name = ai_filters[:brand] || ai_filters["brand"]
        brand = Brand.find_by(name: brand_name)
        rails_filters[:brand_id] = brand&.id
      end
      
      if ai_filters[:category] || ai_filters["category"]
        category_name = ai_filters[:category] || ai_filters["category"]
        category = Category.find_by(name: category_name)
        rails_filters[:category_id] = category&.id
      end
      
      # Handle other filters
      rails_filters[:color] = ai_filters[:color] || ai_filters["color"]
      rails_filters[:style] = ai_filters[:style] || ai_filters["style"]
      rails_filters[:price_range] = ai_filters[:price_range] || ai_filters["price_range"]
      
      # Handle reference product
      if ai_filters[:reference_product] || ai_filters["reference_product"]
        product_name = ai_filters[:reference_product] || ai_filters["reference_product"]
        product = Product.find_by(name: product_name)
        rails_filters[:reference_product_id] = product&.id
      end
      
      # Handle excluded products
      if ai_filters[:excluded_products] || ai_filters["excluded_products"]
        excluded_names = ai_filters[:excluded_products] || ai_filters["excluded_products"]
        excluded_ids = Product.where(name: excluded_names).pluck(:id)
        rails_filters[:excluded_product_ids] = excluded_ids
      end
      
      # Handle diversity boost
      rails_filters[:diversity_boost] = ai_filters[:diversity_boost] || ai_filters["diversity_boost"]
      
      # Add search terms from keywords
      if keywords.any?
        rails_filters[:search_terms] = keywords
      end
      
      rails_filters.compact
    end

    def extract_user_insights_from_section(section_config)
      # Extract user insights from AI-generated section
      {
        section_type: section_config[:type] || section_config["type"],
        conversion_potential: section_config[:conversion_potential] || section_config["conversion_potential"],
        placement_suggestions: section_config[:placement_suggestions] || section_config["placement_suggestions"],
        search_strategy: section_config[:search_strategy] || section_config["search_strategy"]
      }
    end

    def execute_retrieval_strategy(search_strategy, snapshot, profile, session_embed_summary)
      # Execute product retrieval based on AI-generated search strategy
      algorithm = search_strategy[:algorithm]
      filters = search_strategy[:filters]
      limit = search_strategy[:limit]
      
      case algorithm
      when "trending"
        execute_trending_retrieval(filters, limit, snapshot)
      when "similarity"
        execute_similarity_retrieval(filters, limit, snapshot)
      when "complementary"
        execute_complementary_retrieval(filters, limit, snapshot)
      when "diversity"
        execute_diversity_retrieval(filters, limit, snapshot, profile)
      when "completion"
        execute_completion_retrieval(filters, limit, snapshot, profile)
      else
        execute_default_retrieval(filters, limit, snapshot, profile)
      end
    end

    def execute_trending_retrieval(filters, limit, snapshot)
      # Use existing trending retrieval with AI filters
      trending_service = Personalization::Retrieval::Trending.new(
        filters: filters,
        limit: limit,
        context: {
          region: snapshot[:region],
          pickup_only: snapshot[:pickup_only]
        }
      )
      
      trending_service.retrieve
    end

    def execute_similarity_retrieval(filters, limit, snapshot)
      # Use existing similarity retrieval with AI filters
      if filters[:reference_product_id]
        similar_service = Personalization::Retrieval::Lookalikes.new(
          reference_product_id: filters[:reference_product_id],
          filters: filters,
          limit: limit,
          context: {
            region: snapshot[:region],
            pickup_only: snapshot[:pickup_only]
          }
        )
        
        similar_service.retrieve
      else
        execute_default_retrieval(filters, limit, snapshot, {})
      end
    end

    def execute_complementary_retrieval(filters, limit, snapshot)
      # Use complementary product retrieval
      if filters[:reference_product_id]
        complementary_service = Personalization::Retrieval::Complementary.new(
          reference_product_id: filters[:reference_product_id],
          filters: filters,
          limit: limit,
          context: {
            region: snapshot[:region],
            pickup_only: snapshot[:pickup_only]
          }
        )
        
        complementary_service.retrieve
      else
        execute_default_retrieval(filters, limit, snapshot, {})
      end
    end

    def execute_diversity_retrieval(filters, limit, snapshot, profile)
      # Use search fusion with diversity boost
      search_fusion = Personalization::Retrieval::SearchFusion.new(
        filters: filters.merge(diversity_boost: true),
        knobs: { limit: limit, diversity_weight: 0.7 },
        context: {
          region: snapshot[:region],
          pickup_only: snapshot[:pickup_only],
          profile: profile
        }
      )
      
      search_fusion.run
    end

    def execute_completion_retrieval(filters, limit, snapshot, profile)
      # Use behavioral patterns for completion
      completion_type = filters[:completion_type] || "general"
      
      case completion_type
      when "search_completion"
        # Complete user's search intent
        if snapshot[:last_search]
          search_fusion = Personalization::Retrieval::SearchFusion.new(
            filters: filters.merge(search_term: snapshot[:last_search]),
            knobs: { limit: limit },
            context: {
              region: snapshot[:region],
              pickup_only: snapshot[:pickup_only]
            }
          )
          
          search_fusion.run
        else
          execute_default_retrieval(filters, limit, snapshot, profile)
        end
      else
        execute_default_retrieval(filters, limit, snapshot, profile)
      end
    end

    def execute_default_retrieval(filters, limit, snapshot, profile)
      # Default retrieval using search fusion
      search_fusion = Personalization::Retrieval::SearchFusion.new(
        filters: filters,
        knobs: { limit: limit },
        context: {
          region: snapshot[:region],
          pickup_only: snapshot[:pickup_only],
          profile: profile
        }
      )
      
      search_fusion.run
    end

    def build_user_context_for_ai(page)
      # Build user context for AI service
      {
        user_id: current_user&.id,
        session_id: session[:session_id] || "anon_#{SecureRandom.hex(8)}",
        page: page,
        region: params[:region] || "ke",
        timestamp: Time.current.iso8601,
        behavioral_patterns: extract_behavioral_patterns,
        micro_events: extract_micro_events,
        meso_events: extract_meso_events,
        macro_events: extract_macro_events
      }
    end
    
    def extract_behavioral_patterns
      # Extract user behavioral patterns for AI context
      return {} unless current_user
      
      {
        engagement_level: calculate_engagement_level,
        preferred_categories: get_preferred_categories,
        price_sensitivity: calculate_price_sensitivity,
        browsing_patterns: get_browsing_patterns
      }
    end
    
    def extract_micro_events
      # Recent micro-interactions (last 1 hour)
      return [] unless current_user
      
      Event.where(user_id: current_user.id)
           .where('timestamp_utc >= ?', 1.hour.ago)
           .order(timestamp_utc: :desc)
           .limit(20)
           .pluck(:event_name, :payload)
    end
    
    def extract_meso_events
      # Medium-term events (last 24 hours)
      return [] unless current_user
      
      Event.where(user_id: current_user.id)
           .where('timestamp_utc >= ?', 24.hours.ago)
           .order(timestamp_utc: :desc)
           .limit(50)
           .pluck(:event_name, :payload)
    end
    
    def extract_macro_events
      # Long-term events (last 7 days)
      return [] unless current_user
      
      Event.where(user_id: current_user.id)
           .where('timestamp_utc >= ?', 7.days.ago)
           .order(timestamp_utc: :desc)
           .limit(100)
           .pluck(:event_name, :payload)
    end
    
    def calculate_engagement_level
      return 'low' unless current_user
      
      recent_events = Event.where(user_id: current_user.id)
                          .where('timestamp_utc >= ?', 7.days.ago)
                          .count
      
      case recent_events
      when 0..5 then 'low'
      when 6..20 then 'medium'
      else 'high'
      end
    end
    
    def get_preferred_categories
      return [] unless current_user

      Event.where(user_id: current_user.id)
           .where(event_name: 'product_impression')
           .where('timestamp_utc >= ?', 30.days.ago)
           .joins('JOIN products ON products.id = CAST(events.payload->>\'product_id\' AS INTEGER)')
           .joins('JOIN categories ON categories.id = products.category_id')
           .group('categories.name')
           .order(Arel.sql('COUNT(*) DESC'))
           .limit(5)
           .pluck('categories.name')
    end
    
    def calculate_price_sensitivity
      return 'unknown' unless current_user
      
      # This would need more sophisticated analysis
      'medium'
    end
    
    def get_browsing_patterns
      return {} unless current_user
      
      {
        avg_session_duration: calculate_avg_session_duration,
        pages_per_session: calculate_pages_per_session,
        time_of_day_preference: get_time_of_day_preference
      }
    end
    
    def calculate_avg_session_duration
      # Simplified calculation
      return 0 unless current_user
      
      sessions = Event.where(user_id: current_user.id)
                     .where('timestamp_utc >= ?', 7.days.ago)
                     .group(:session_id)
                     .count
      
      sessions.size > 0 ? sessions.values.sum / sessions.size : 0
    end
    
    def calculate_pages_per_session
      # Simplified calculation
      return 0 unless current_user
      
      page_views = Event.where(user_id: current_user.id)
                       .where(event_name: 'page_view')
                       .where('timestamp_utc >= ?', 7.days.ago)
                       .count
      
      sessions = Event.where(user_id: current_user.id)
                     .where('timestamp_utc >= ?', 7.days.ago)
                     .distinct
                     .count(:session_id)
      
      sessions > 0 ? page_views / sessions : 0
    end
    
    def get_time_of_day_preference
      return 'unknown' unless current_user
      
      # Simplified - would need more analysis
      'afternoon'
    end

    def get_ai_personalized_sections(user_context)
      # Call AI service to get personalized sections
      Personalization::PlannerClient.fetch_plan(
        page: user_context[:page],
        snapshot: user_context,
        profile: Personalization::ProfileStore.slice(user_context[:user_id]),
        session_embed_summary: build_session_embed_summary(user_context[:session_id]),
        constraints: {}
      )
    end

    def process_ai_sections_for_frontend(ai_sections, user_context)
      # Process AI sections for frontend consumption
      ai_sections.map do |section_config|
        process_ai_personalized_section(
          section_config: section_config,
          snapshot: user_context,
          profile: Personalization::ProfileStore.slice(user_context[:user_id]),
          session_embed_summary: build_session_embed_summary(user_context[:session_id]),
          position: ai_sections.index(section_config)
        )
      end.compact
    end

    def optimize_section_placement(sections, page)
      # Optimize section placement based on conversion potential and page context
      case page
      when "home"
        optimize_home_placement(sections)
      when "pdp"
        optimize_pdp_placement(sections)
      when "wishlist"
        optimize_wishlist_placement(sections)
      when "checkout"
        optimize_checkout_placement(sections)
      else
        sections
      end
    end

    def optimize_home_placement(sections)
      # Home page: High conversion at top, discovery throughout
      high_conversion = sections.select { |s| s[:conversion_potential] == "high" }
      medium_conversion = sections.select { |s| s[:conversion_potential] == "medium" }
      low_conversion = sections.select { |s| s[:conversion_potential] == "low" }
      
      # Mix sections for optimal engagement
      [high_conversion, medium_conversion, low_conversion].flatten.compact
    end

    def optimize_pdp_placement(sections)
      # PDP: Similar and complementary below product
      similar_sections = sections.select { |s| s[:type] == "similar" }
      complementary_sections = sections.select { |s| s[:type] == "complementary" }
      other_sections = sections.reject { |s| ["similar", "complementary"].include?(s[:type]) }
      
      [similar_sections, complementary_sections, other_sections].flatten.compact
    end

    def optimize_wishlist_placement(sections)
      # Wishlist: Re-engagement and trending
      trending_sections = sections.select { |s| s[:type] == "trending" }
      similar_sections = sections.select { |s| s[:type] == "similar" }
      other_sections = sections.reject { |s| ["trending", "similar"].include?(s[:type]) }
      
      [trending_sections, similar_sections, other_sections].flatten.compact
    end

    def optimize_checkout_placement(sections)
      # Checkout: Upsell and completion
      complementary_sections = sections.select { |s| s[:type] == "complementary" }
      completion_sections = sections.select { |s| s[:type] == "completion" }
      other_sections = sections.reject { |s| ["complementary", "completion"].include?(s[:type]) }
      
      [complementary_sections, completion_sections, other_sections].flatten.compact
    end

    def build_session_embed_summary(session_id)
      # Simplified session embedding summary
      sid = session_id.to_s
      sid = "anon_#{SecureRandom.hex(8)}" if sid.blank?
      {
        topics: ["general_interest"],
        centroid_bucket: Digest::SHA256.hexdigest(sid)[0..11]
      }
    end

    def execute_plan_sections(plan, snapshot, profile, session_embed_summary)
      sections = []
      
      # Process AI-generated personalized sections
      if plan[:personalized_sections] || plan["personalized_sections"]
        # New AI response format with personalized sections
        ai_sections = plan[:personalized_sections] || plan["personalized_sections"]
        
        ai_sections.each_with_index do |section_config, index|
          section_data = process_ai_personalized_section(
            section_config: section_config,
            snapshot: snapshot,
            profile: profile,
            session_embed_summary: session_embed_summary,
            position: index
          )
          
          sections << section_data if section_data
        end
      else
        # Legacy plan format (fallback)
        plan_sections = plan[:sections] || plan["sections"] || []
        
        plan_sections.each_with_index do |section_config, index|
          section_id = section_config[:id] || section_config["id"]
          section_title = section_config[:title] || section_config["title"] || "Products"
          section_type = section_config[:type] || section_config["type"] || "general"
          
          section_data = process_ai_section(
            section_id: section_id,
            section_title: section_title,
            section_type: section_type,
            section_config: section_config,
            snapshot: snapshot,
            profile: profile,
            session_embed_summary: session_embed_summary,
            position: index
          )
          
          sections << section_data if section_data
        end
      end
      merchant_counts = {}
      
      # Handle both old and new plan formats
      plan_sections = plan[:sections] || plan.dig(:page_plans, snapshot[:page], :sections) || []
      
      plan_sections.each do |section_config|
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
        
        # Build section response
        section = {
          id: section_config[:id],
          title: section_config[:title] || section_config[:id].humanize,
          reason: section_config[:reason],
          products: Personalization::ResponseShaper.build_lite_products(
            final_items.map { |item| item[:id].to_s }
          ),
          pre_guard_candidates: candidates,
          guardrail_drops: guardrails_result[:drop_reasons],
          retrieval_latency: 0, # Would be measured in real implementation
          guardrails_latency: 0,
          coordination_latency: 0,
          total_latency: 0
        }
        
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

    # ---------- JSON shaping helpers ----------
    # Sectioned response wrapper
    def sectioned_response(feed:, plan_id:, items:, lite:, reasons:, slice:, ttl_seconds:, is_cache_hit:, intent: nil, trace_versions: nil)
      response = {
        feed_id:     feed.feed_uid,
        plan_id:     plan_id,
        ttl_seconds: ttl_seconds,
        sections: [
          {
            id: "grid",
            reason: nil,
            products: lite
          }
        ],
        cursor: slice[:cursor],
        hasMore: slice[:has_more],
        trace: (trace_versions || { prompt_version: feed.prompt_version, model_version: feed.model_version, index_version: feed.index_version }),
        is_cache_hit: is_cache_hit,
        intent: intent
      }
      
      # Add experiment data if present
      if feed.experiment_key.present? && feed.variant.present?
        response[:experiment] = {
          key: feed.experiment_key,
          variant: feed.variant
        }
      end
      
      response
    end

    def coerce_images(val)
      arr =
        case val
        when Array then val
        when String
          begin
            parsed = JSON.parse(val)
            parsed.is_a?(Array) ? parsed : []
          rescue JSON::ParserError
            []
          end
        else
          []
        end
      arr.map { |u| u.to_s.presence }.compact.first(MAX_SUPP_IMAGES)
    end

    def main_image_or_fallback(main_image, supp_arr)
      (main_image.to_s.presence) || supp_arr.first.to_s.presence
    end

    # Minimal product shape for cards, preserving order
    def build_lite_products(ids_as_strings)
      ids = Array(ids_as_strings).map(&:to_i)
      return [] if ids.empty?

      records = ::Product
                  .includes(:shop)
                  .where(id: ids)
                  .select(:id, :name, :price, :main_image, :supplementary_images, :shop_id)

      by_id = {}
      records.each do |p|
        supp       = coerce_images(p.supplementary_images)
        main       = main_image_or_fallback(p.main_image, supp)
        image_alias = main || supp.first

        by_id[p.id] = {
          id:   p.id,
          name: p.name.to_s,
          price: p.price.to_s,
          image: image_alias.to_s,
          main_image: main.to_s.presence,
          supplementary_images: supp,
          shop: {
            id: p.shop_id,
            name: p.shop&.name.to_s,
            store_logo_url: p.shop&.store_logo_url.to_s.presence
          }
        }
      end

      ids.map { |pid| by_id[pid] }.compact
    end

    # Fallback that STILL returns a real feed_id and ALL sections populated
    def popular_fallback(snapshot:, limit:, reason:)
      snap = (snapshot || {}).with_indifferent_access
      snap[:page] ||= "home"
      snap[:session_id] ||= "anon_#{SecureRandom.hex(8)}"

      base_scope = Product.where("stock > 0")
                          .where(moderation_status: "approved")
                          .where(pickup_ready: true)

      # Build ids for each section
      trending_ids = base_scope.order(created_at: :desc).limit(12).pluck(:id).map(&:to_s)
      # Build a larger pool so fallback supports real pagination
      grid_pool_ids = base_scope.order(created_at: :desc).limit(MAX_POOL).pluck(:id).map(&:to_s)
      grid_slice    = Personalization::Paginator.slice(items: grid_pool_ids, cursor: nil, limit: limit)
      fresh_ids    = base_scope.order(Arel.sql('RANDOM()')).limit(12).pluck(:id).map(&:to_s)
      liked_v_ids  = base_scope.order(Arel.sql('RANDOM()')).limit(12).pluck(:id).map(&:to_s)
      liked_p_ids  = base_scope.order(Arel.sql('RANDOM()')).limit(12).pluck(:id).map(&:to_s)

      trace_versions = { prompt_version: "fallback", model_version: reason.to_s, index_version: "catalog" }
      fp = "fallback:#{Digest::SHA256.hexdigest([
        snap[:user_id].to_s,
        snap[:session_id].to_s,
        snap[:page].to_s,
        reason.to_s
      ].join("|"))}"

      # Persist feed using the full grid pool for stable pagination via /next
      ranked = grid_pool_ids.map { |id| { id: id } }
      plan_id = "control_fallback_v1"
      feed, _reasons_map = Personalization::SlateWriter.persist!(
        snapshot:     snap,
        fingerprint:  fp,
        ranked_items: ranked,
        ttl_seconds:  FALLBACK_TTL_SEC,
        versions:     trace_versions,
        plan_id:      plan_id
      )

      Personalization::FingerprintCache.store!(
        fingerprint: fp,
        feed:        feed,
        items:       grid_pool_ids,
        reasons:     {},
        ttl_seconds: FALLBACK_TTL_SEC
      )

      sections = []
      sections << {
        id: "trending_near_you",
        type: "horizontal",
        title: "Trending near you",
        reason: "Popular picks",
        products: build_lite_products(trending_ids),
        count: trending_ids.count,
        cursor: nil,
        has_more: false
      }
      sections << {
        id: "grid",
        type: "grid",
        title: "For you",
        reason: nil,
        products: build_lite_products(grid_slice[:items]),
        count: grid_slice[:items].count,
        cursor: grid_slice[:cursor],
        has_more: grid_slice[:has_more]
      }
      sections << {
        id: "fresh_in_favorites",
        type: "horizontal",
        title: "New in favourites",
        reason: "Fresh picks you may like",
        positionAfter: 12,
        products: build_lite_products(fresh_ids),
        count: fresh_ids.count,
        cursor: nil,
        has_more: false
      }
      sections << {
        id: "lookalikes_since_viewed",
        type: "horizontal",
        title: "Since you liked",
        reason: "Similar to your browsing",
        positionAfter: 36,
        products: build_lite_products(liked_v_ids),
        count: liked_v_ids.count,
        cursor: nil,
        has_more: false
      }
      sections << {
        id: "lookalikes_since_purchased",
        type: "horizontal",
        title: "Complete the look",
        reason: "Pairs well with your picks",
        positionAfter: 60,
        products: build_lite_products(liked_p_ids),
        count: liked_p_ids.count,
        cursor: nil,
        has_more: false
      }

      {
        feed_id: feed.feed_uid,
        plan_id: plan_id,
        ttl_seconds: FALLBACK_TTL_SEC,
        sections: sections,
        trace: trace_versions,
        is_cache_hit: false,
        intent: nil
      }
    end

    # ---- Utilities borrowed from DemoController ----
    def add_cache_headers(response, data_type, soft_ttl, hard_ttl)
      case data_type
      when 'lite_data', 'full_data', 'section_window'
        response.headers['Cache-Control'] = "public, max-age=#{soft_ttl.to_i}, s-maxage=#{hard_ttl.to_i}"
        response.headers['X-Cache-TTL'] = soft_ttl.to_i
        response.headers['X-Cache-Hard-TTL'] = hard_ttl.to_i
      end
      response.headers['X-Data-Type'] = data_type
    end

    def track_performance(endpoint, start_time_mono, response_size)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time_mono) * 1000.0)
      Rails.logger.info("[Performance] #{endpoint}: #{duration_ms.round(2)}ms, #{response_size} bytes")
      Rails.cache.write("metrics:#{endpoint}:#{Time.current.to_i}", { duration_ms:, response_size:, ts: Time.current }, expires_in: 1.hour)
    end

    def render_error(error_code, message, details = {}, status = :bad_request)
      render json: { error: error_code, message: message, details: details, timestamp: Time.current.iso8601 }, status: status
    end

    def validate_required_params(required_params)
      missing = required_params.select { |param| params[param].blank? }
      if missing.any?
        render_error('missing_parameters', "Missing required parameters: #{missing.join(', ')}", { missing: missing }, :bad_request)
        return false
      end
      true
    end

    def check_rate_limit(user_id, ip_address)
      # Per user rate limiting
      user_key = "rate_limit:user:#{user_id || 'guest'}"
      user_requests = Rails.cache.read(user_key) || 0
      if user_requests >= 100
        render_error('rate_limit_exceeded', 'Too many requests. Please try again later.', { limit: 100, window: '1 minute' }, :too_many_requests)
        return false
      end

      # Per IP rate limiting
      ip_key = "rate_limit:ip:#{ip_address}"
      ip_requests = Rails.cache.read(ip_key) || 0
      if ip_requests >= 1000
        render_error('rate_limit_exceeded', 'Too many requests from this IP. Please try again later.', { limit: 1000, window: '1 minute' }, :too_many_requests)
        return false
      end

      Rails.cache.write(user_key, user_requests + 1, expires_in: 1.minute)                                  
      Rails.cache.write(ip_key, ip_requests + 1, expires_in: 1.minute)  
      true
    end

    # Home Grid Analytics and Fallback Methods
    def track_home_page_analytics(playbook_response, modules, user_context)
      begin
        # Track page view
        track_event('page_view', {
          page: 'home',
          playbook_id: playbook_response[:playbook_id],
          ai_generated: playbook_response[:metadata][:ai_generated],
          user_personalized: playbook_response[:metadata][:user_personalized]
        }, user_context)
        
        # Track feed impressions for each module
        modules.each do |module_data|
          track_event('feed_impression', {
            feed_id: module_data[:id],
            feed_type: module_data[:type],
            placement: module_data[:placement],
            products: module_data[:items]&.map { |item| item[:id] },
            product_count: module_data[:items]&.size || 0
          }, user_context)
        end
        
        # Track playbook execution metrics
        track_event('playbook_executed', {
          playbook_id: playbook_response[:playbook_id],
          page: 'home',
          module_count: modules.size,
          processing_time_ms: playbook_response[:metadata][:processing_time_ms],
          ai_generated: playbook_response[:metadata][:ai_generated]
        }, user_context)
        
      rescue => e
        Rails.logger.error "Analytics tracking failed: #{e.message}"
        # Don't let analytics errors break the main flow
      end
    end
    
    def track_error_analytics(error, user_context)
      begin
        track_event('api_error', {
          page: 'home',
          error_type: error.class.name,
          error_message: error.message,
          endpoint: 'home_grid'
        }, user_context)
      rescue => e
        Rails.logger.error "Error analytics tracking failed: #{e.message}"
      end
    end
    
    def is_cold_start_user?(user_context)
      return true if user_context[:user_id].nil? # Anonymous users are always cold start
      
      # Check if user has any behavioral events in the last 30 days
      event_count = Event
        .where(user_id: user_context[:user_id])
        .where('timestamp_utc >= ?', 30.days.ago)
        .where(event_name: ['product_impression', 'product_click', 'add_to_cart', 'wishlist_add'])
        .count
      
      event_count < 5 # Less than 5 interactions = cold start
    end
    
    def track_cold_start_analytics(user_context)
      begin
        track_event('cold_start_detected', {
          page: 'home',
          user_type: user_context[:user_id] ? 'registered' : 'anonymous',
          fallback_triggered: true
        }, user_context)
      rescue => e
        Rails.logger.error "Cold start analytics tracking failed: #{e.message}"
      end
    end
    
    def track_fallback_analytics(playbook_response, user_context)
      begin
        track_event('fallback_triggered', {
          page: 'home',
          playbook_id: playbook_response[:playbook_id],
          reason: 'empty_playbook_response',
          module_count: playbook_response[:modules]&.size || 0
        }, user_context)
      rescue => e
        Rails.logger.error "Fallback analytics tracking failed: #{e.message}"
      end
    end
    
    def track_event(event_name, payload, user_context)
      # Create event record for analytics
      event_data = {
        event_id: SecureRandom.uuid,
        user_id: user_context[:user_id],
        session_id: user_context[:session_id],
        event_name: event_name,
        timestamp_utc: Time.current.utc,
        page: 'home',
        region: user_context[:region],
        geohash6: user_context[:geohash6],
        payload: payload
      }
      
      # Store event in database
      Event.create!(event_data)
      
      # Track cost metrics
      Personalization::CostMeter.track_event_ingestion!(
        plan_id: 'home_analytics_v1',
        events_count: 1
      )
      
    rescue => e
      Rails.logger.error "Event tracking failed for #{event_name}: #{e.message}"
    end
    
    def process_home_modules(modules)
      modules.map do |module_data|
        {
          id: module_data[:id],
          type: module_data[:type],
          placement: module_data[:placement],
          items: build_lite_products(module_data[:items]),
          metadata: module_data[:metadata]
        }
      end
    end
    
    def extract_trending_strip(modules)
      trending_module = modules.find { |m| m[:placement] == 'home_top' }
      return nil unless trending_module
      
      {
        id: trending_module[:id],
        title: generate_trending_title(trending_module),
        type: 'horizontal',
        items: trending_module[:items],
        metadata: trending_module[:metadata]
      }
    end
    
    def extract_discovery_grid(modules)
      discovery_module = modules.find { |m| m[:placement] == 'home_discovery' }
      return nil unless discovery_module
      
      {
        id: discovery_module[:id],
        title: 'Discover New Styles',
        type: 'grid',
        items: discovery_module[:items],
        metadata: discovery_module[:metadata]
      }
    end
    
    def extract_dynamic_injections(modules)
      injection_modules = modules.select { |m| m[:placement].start_with?('home_injection') }
      
      injection_modules.map do |module_data|
        {
          id: module_data[:id],
          title: generate_injection_title(module_data),
          type: 'horizontal',
          items: module_data[:items],
          placement: module_data[:placement],
          metadata: module_data[:metadata]
        }
      end
    end
    
    def generate_trending_title(module_data)
      case module_data[:id]
      when /sneakers/
        'Trending in Sneakers'
      when /dresses/
        'Trending in Dresses'
      when /jackets/
        'Trending in Jackets'
      when /vintage/
        'Trending in Vintage'
      when /streetwear/
        'Trending in Streetwear'
      else
        'Trending Near You'
      end
    end
    
    def generate_injection_title(module_data)
      case module_data[:type]
      when 'similar'
        'Since You Liked'
      when 'complementary'
        'Complete the Look'
      when 'trending'
        'Trending in Your Style'
      when 'discovery'
        'Fresh in Your Favorites'
      else
        'Recommended for You'
      end
    end
    
    def build_lite_products(product_ids)
      return [] unless product_ids&.any?
      
      products = Product.where(id: product_ids)
                       .includes(:shop, :brand, :category)
                       .limit(50)
      
      products.map do |product|
        {
          id: product.id,
          name: product.name,
          price: product.price,
          image_url: product.main_image,
          shop: {
            id: product.shop.id,
            name: product.shop.name,
            store_logo_url: product.shop&.store_logo_url
          },
          brand: product.brand&.name,
          category: product.category&.name
        }
      end
    end
    
    def render_home_fallback_response
      # Get fallback content for cold start users
      page = params[:page]&.to_i || 1
      fallback_content = get_fallback_content(page, [])
      
      render json: {
        page: 'home',
        layout: {
          trending_strip: fallback_content[:trending_strip],
          discovery_grid: fallback_content[:discovery_grid],
          dynamic_injections: fallback_content[:dynamic_injections]
        },
        metadata: {
          ai_generated: false,
          user_personalized: false,
          processing_time_ms: 0,
          pagination: {
            current_page: page,
            has_more: page < 5, # Assume 5 pages max for fallback
            total_pages: 5
          }
        }
      }
    end
    
    def get_fallback_content(page = 1, excluded_ids = [])
      # Get trending products for fallback (different for each page)
      trending_products = get_trending_fallback_products(8, page, excluded_ids)
      
      # Get popular categories for discovery (different for each page)
      discovery_products = get_discovery_fallback_products(20, page, excluded_ids)
      
      # Get dynamic injections for this page
      dynamic_injections = get_fallback_dynamic_injections(page, excluded_ids)
      
      {
        trending_strip: page == 1 ? {
          title: 'Trending Near You',
          products: trending_products,
          reason: 'popular_this_week'
        } : nil,
        discovery_grid: {
          title: 'Discover More',
          products: discovery_products,
          reason: 'based_on_your_taste'
        },
        dynamic_injections: dynamic_injections
      }
    end
    
    def get_trending_fallback_products(limit, page, excluded_ids)
      # Calculate offset to get different products for each page
      offset = (page - 1) * limit
      
      # Get most viewed products in the last 7 days
      trending_ids = Event
        .where(event_name: 'product_impression')
        .where('timestamp_utc >= ?', 7.days.ago)
        .where("payload->>'product_id' IS NOT NULL")
        .where.not("payload->>'product_id'": excluded_ids)
        .group(Arel.sql("payload->>'product_id'"))
        .order(Arel.sql('COUNT(*) DESC'))
        .offset(offset)
        .limit(limit)
        .pluck(Arel.sql("payload->>'product_id'"))
        .compact
      
      # If no trending data, get recent products with different ordering per page
      if trending_ids.empty?
        # Use different ordering strategies per page to ensure variety
        case page % 3
        when 1
          # Page 1, 4, 7... - Most recent
          trending_ids = Product
            .joins(:shop)
            .where.not(id: excluded_ids)
            .order(created_at: :desc)
            .offset(offset)
            .limit(limit)
            .pluck(:id)
        when 2
          # Page 2, 5, 8... - Most viewed
          trending_ids = Product
            .joins(:shop)
            .where.not(id: excluded_ids)
            .order(views: :desc, created_at: :desc)
            .offset(offset)
            .limit(limit)
            .pluck(:id)
        else
          # Page 3, 6, 9... - Random
          trending_ids = Product
            .joins(:shop)
            .where.not(id: excluded_ids)
            .order(Arel.sql('RANDOM()'))
            .offset(offset)
            .limit(limit)
            .pluck(:id)
        end
      end
      
      build_lite_products(trending_ids)
    end
    
    def get_discovery_fallback_products(limit, page, excluded_ids)
      # Calculate offset to get different products for each page
      offset = (page - 1) * limit
      
      # Get products from popular categories with different strategies per page
      popular_categories = Category
        .joins(:products)
        .group('categories.id')
        .order(Arel.sql('COUNT(products.id) DESC'))
        .limit(4)
        .pluck(:id)
      
      # Use different ordering strategies per page to ensure variety
      case page % 4
      when 1
        # Page 1, 5, 9... - Random from popular categories
        discovery_ids = Product
          .joins(:shop, :category)
          .where(categories: { id: popular_categories })
          .where.not(id: excluded_ids)
          .order(Arel.sql('RANDOM()'))
          .offset(offset)
          .limit(limit)
          .pluck(:id)
      when 2
        # Page 2, 6, 10... - Most recent from popular categories
        discovery_ids = Product
          .joins(:shop, :category)
          .where(categories: { id: popular_categories })
          .where.not(id: excluded_ids)
          .order(created_at: :desc)
          .offset(offset)
          .limit(limit)
          .pluck(:id)
      when 3
        # Page 3, 7, 11... - Most viewed from popular categories
        discovery_ids = Product
          .joins(:shop, :category)
          .where(categories: { id: popular_categories })
          .where.not(id: excluded_ids)
          .order(views: :desc, created_at: :desc)
          .offset(offset)
          .limit(limit)
          .pluck(:id)
      else
        # Page 4, 8, 12... - Price-based ordering
        discovery_ids = Product
          .joins(:shop, :category)
          .where(categories: { id: popular_categories })
          .where.not(id: excluded_ids)
          .order(:price, created_at: :desc)
          .offset(offset)
          .limit(limit)
          .pluck(:id)
      end
      
      build_lite_products(discovery_ids)
    end
    
    def get_category_fallback_products(limit, page, excluded_ids)
      # Create category-specific trending strips with pagination
      categories = Category.limit(3).pluck(:id, :name)
      
      categories.map do |category_id, category_name|
        # Calculate offset to get different products for each page
        offset = (page - 1) * limit
        
        # Use different ordering strategies per page to ensure variety
        case page % 3
        when 1
          # Page 1, 4, 7... - Random
          category_products = Product
            .joins(:shop)
            .where(category_id: category_id)
            .where.not(id: excluded_ids)
            .order(Arel.sql('RANDOM()'))
            .offset(offset)
            .limit(limit)
            .pluck(:id)
        when 2
          # Page 2, 5, 8... - Most recent
          category_products = Product
            .joins(:shop)
            .where(category_id: category_id)
            .where.not(id: excluded_ids)
            .order(created_at: :desc)
            .offset(offset)
            .limit(limit)
            .pluck(:id)
        else
          # Page 3, 6, 9... - Most viewed
          category_products = Product
            .joins(:shop)
            .where(category_id: category_id)
            .where.not(id: excluded_ids)
            .order(views: :desc, created_at: :desc)
            .offset(offset)
            .limit(limit)
            .pluck(:id)
        end
        
        {
          id: "trending_#{category_name.downcase}_page_#{page}",
          title: "Trending in #{category_name}",
          type: 'horizontal',
          items: build_lite_products(category_products),
          placement: "home_injection_#{page}",
          metadata: { 
            reason: 'fallback',
            source: 'category_trending',
            category: category_name,
            product_count: category_products.size,
            page: page
          }
        }
      end
    end
    
    # Fallback injection method for when AI doesn't provide injections
    def get_fallback_injections(page, user_context)
      # Get basic category injections as fallback
      get_category_fallback_products(8, page, [])
    end
    
    # Get fallback dynamic injections with proper format
    def get_fallback_dynamic_injections(page, excluded_ids = [])
      case page
      when 1
        # First page: 3 sections - Trending in your region + Men's + Women's
        [
          {
            slot: 'top',
            module: 'trending_in_region',
            title: 'Trending in Your Region',
            products: get_trending_products_for_injection(8, excluded_ids, page),
            reason: 'trending_in_region'
          },
          {
            slot: 'middle',
            module: 'trending_mens_clothing',
            title: 'Trending in Men\'s Clothing',
            products: get_category_products_for_injection('mens', 8, excluded_ids, page),
            reason: 'trending_mens_clothing'
          },
          {
            slot: 'bottom',
            module: 'trending_womens_clothing',
            title: 'Trending in Women\'s Clothing',
            products: get_category_products_for_injection('womens', 8, excluded_ids, page),
            reason: 'trending_womens_clothing'
          }
        ]
      when 2
        # Second page: 1 section - Trending in Electronics
        [{
          slot: 'middle',
          module: 'trending_electronics',
          title: 'Trending in Electronics',
          products: get_category_products_for_injection('electronics', 8, excluded_ids, page),
          reason: 'trending_electronics'
        }]
      when 3
        # Third page: 1 section - Trending in Computers
        [{
          slot: 'middle',
          module: 'trending_computers',
          title: 'Trending in Computers',
          products: get_category_products_for_injection('computers', 8, excluded_ids, page),
          reason: 'trending_computers'
        }]
      else
        # Subsequent pages: 1 section - Rotating categories
        category = get_rotating_category_for_page(page)
        [{
          slot: 'middle',
          module: "trending_in_#{category}",
          title: "Trending in #{category.humanize}",
          products: get_category_products_for_injection(category, 8, excluded_ids, page),
          reason: "trending_in_#{category}"
        }]
      end
    end
    
    # Get trending products for injection (fallback when no specific category)
    def get_trending_products_for_injection(limit, excluded_ids = [], page = 1)
      # Calculate offset to get different products for each page
      offset = (page - 1) * limit
      
      # First try to get products with actual views/impressions
      trending_ids = Event
        .where(event_name: 'product_impression')
        .where('timestamp_utc >= ?', 7.days.ago)
        .where("payload->>'product_id' IS NOT NULL")
        .where.not("payload->>'product_id'": excluded_ids)
        .group(Arel.sql("payload->>'product_id'"))
        .order(Arel.sql('COUNT(*) DESC'))
        .offset(offset)
        .limit(limit)
        .pluck(Arel.sql("payload->>'product_id'"))
        .compact
      
      if trending_ids.any?
        # Get the actual trending products
        products = Product.joins(:shop, :category)
                         .where(id: trending_ids)
                         .where("stock > 0")
                         .where(moderation_status: "approved")
        build_lite_products(products.pluck(:id))
      else
        # Fallback to recent popular products with different ordering per page
        case page % 3
        when 1
          # Page 1, 4, 7... - Most viewed
          products = Product.joins(:shop, :category)
                           .where("stock > 0")
                           .where(moderation_status: "approved")
                           .where.not(id: excluded_ids)
                           .order(views: :desc, created_at: :desc)
                           .offset(offset)
                           .limit(limit)
        when 2
          # Page 2, 5, 8... - Most recent
          products = Product.joins(:shop, :category)
                           .where("stock > 0")
                           .where(moderation_status: "approved")
                           .where.not(id: excluded_ids)
                           .order(created_at: :desc)
                           .offset(offset)
                           .limit(limit)
        else
          # Page 3, 6, 9... - Random
          products = Product.joins(:shop, :category)
                           .where("stock > 0")
                           .where(moderation_status: "approved")
                           .where.not(id: excluded_ids)
                           .order(Arel.sql('RANDOM()'))
                           .offset(offset)
                           .limit(limit)
        end
        build_lite_products(products.pluck(:id))
      end
    end
    
    # Get products for specific category injection
    def get_category_products_for_injection(category, limit, excluded_ids = [], page = 1)
      # Calculate offset to get different products for each page
      offset = (page - 1) * limit
      
      # Map category names to actual category searches
      category_mappings = {
        'mens' => ['men', 'mens', 'male', 'clothing'],
        'womens' => ['women', 'womens', 'female', 'clothing'],
        'electronics' => ['electronics', 'gadgets', 'tech', 'computers'],
        'computers' => ['computers', 'laptops', 'desktops', 'electronics'],
        'fashion' => ['fashion', 'clothing', 'apparel', 'style'],
        'beauty' => ['beauty', 'cosmetics', 'skincare', 'makeup'],
        'home' => ['home', 'furniture', 'decor', 'household'],
        'sports' => ['sports', 'fitness', 'exercise', 'athletic']
      }
      
      # Get search terms for the category
      search_terms = category_mappings[category.downcase] || [category.downcase]
      
      # Try to find products that match the category
      products = Product.joins(:shop, :category)
                       .where("stock > 0")
                       .where(moderation_status: "approved")
                       .where.not(id: excluded_ids)
      
      # Build search conditions step by step
      search_conditions = []
      search_params = []
      
      # Add category name searches
      search_terms.each do |term|
        search_conditions << "categories.name ILIKE ?"
        search_params << "%#{term}%"
      end
      
      # Add product name/description searches
      search_terms.each do |term|
        search_conditions << "products.name ILIKE ?"
        search_conditions << "products.description ILIKE ?"
        search_params << "%#{term}%"
        search_params << "%#{term}%"
      end
      
      # Apply the search conditions
      if search_conditions.any?
        products = products.where(search_conditions.join(" OR "), *search_params)
      end
      
      # If no products found with category matching, try broader search
      if products.empty?
        products = Product.joins(:shop, :category)
                         .where("stock > 0")
                         .where(moderation_status: "approved")
                         .where.not(id: excluded_ids)
                         .where("products.name ILIKE ? OR products.description ILIKE ?", 
                                "%#{search_terms.first}%", "%#{search_terms.first}%")
      end
      
      # If still no products, get trending products as last resort
      if products.empty?
        products = Product.joins(:shop, :category)
                         .where("stock > 0")
                         .where(moderation_status: "approved")
                         .where.not(id: excluded_ids)
                         .order(views: :desc, created_at: :desc)
      end
      
      # Use different ordering strategies per page to ensure variety
      case page % 3
      when 1
        # Page 1, 4, 7... - Random
        products = products.order(Arel.sql('RANDOM()'))
      when 2
        # Page 2, 5, 8... - Most recent
        products = products.order(created_at: :desc)
      else
        # Page 3, 6, 9... - Most viewed
        products = products.order(views: :desc, created_at: :desc)
      end
      
      products.offset(offset).limit(limit)
      build_lite_products(products.pluck(:id))
    end
    
    # Get discounted products for price drop alert
    def get_discounted_products_for_injection(limit, excluded_ids = [])
      # Get products with price reductions (simulated)
      products = Product.joins(:shop, :category)
                       .where("stock > 0")
                       .where(moderation_status: "approved")
                       .where.not(id: excluded_ids)
                       .order(Arel.sql('RANDOM()'))
                       .limit(limit)
      
      build_lite_products(products.pluck(:id))
    end
    
    # Get rotating category for page
    def get_rotating_category_for_page(page)
      categories = ['fashion', 'beauty', 'electronics', 'home', 'sports', 'books', 'toys', 'jewelry']
      categories[(page - 1) % categories.length]
    end
    
    # Format home grid response according to specification
    def format_home_grid_response(response, page)
      processed_modules = response[:processed_modules]
      
      # Extract trending strip (only for page 1)
      trending_strip = page == 1 ? extract_trending_strip(processed_modules) : nil
      
      # Extract discovery grid
      discovery_grid = extract_discovery_grid(processed_modules)
      
      # Extract dynamic injections
      dynamic_injections = extract_dynamic_injections(processed_modules, page)
      
      {
        page: 'home',
        layout: {
          trending_strip: trending_strip,
          discovery_grid: discovery_grid,
          dynamic_injections: dynamic_injections
        },
        metadata: {
          ai_generated: response[:metadata][:ai_generated] || true,
          user_personalized: response[:metadata][:user_personalized] || true,
          processing_time_ms: response[:metadata][:processing_time_ms],
          pagination: {
            current_page: page,
            has_more: response[:metadata][:has_more] || true,
            total_pages: response[:metadata][:total_pages] || 5
          }
        }
      }
    end
    
    # Extract trending strip from processed modules
    def extract_trending_strip(processed_modules)
      trending_module = processed_modules.find { |m| m[:placement] == 'home_trending' }
      return nil unless trending_module
      
      {
        title: 'Trending Near You',
        products: trending_module[:items] || [],
        reason: 'popular_this_week'
      }
    end
    
    # Extract discovery grid from processed modules
    def extract_discovery_grid(processed_modules)
      discovery_module = processed_modules.find { |m| m[:placement] == 'home_discovery' }
      return { title: 'Discover More', products: [], reason: 'based_on_your_taste' } unless discovery_module
      
      {
        title: 'Discover More',
        products: discovery_module[:items] || [],
        reason: 'based_on_your_taste'
      }
    end
    
    # Extract dynamic injections from processed modules
    def extract_dynamic_injections(processed_modules, page)
      injection_modules = processed_modules.select { |m| m[:placement]&.include?('injection') }
      
      injection_modules.map.with_index do |module_data, index|
        {
          slot: get_injection_slot(index, page),
          module: module_data[:id] || "injection_#{index}",
          title: module_data[:title] || "Recommended",
          products: module_data[:items] || [],
          reason: module_data[:metadata]&.dig(:reason) || 'personalized_for_you'
        }
      end
    end
    
    # Get injection slot based on index and page
    def get_injection_slot(index, page)
      case page
      when 1
        index == 0 ? 'top' : 'bottom'
      when 2
        index == 0 ? 'middle' : 'bottom'
      else
        index == 0 ? 'top' : 'middle'
      end
    end
  end
end
