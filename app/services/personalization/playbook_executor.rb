# app/services/personalization/playbook_executor.rb
# frozen_string_literal: true

module Personalization
  class PlaybookExecutor
    include ActiveSupport::Configurable
    
    # Configuration
    config_accessor :max_execution_time_ms, :fallback_enabled, :cache_ttl_seconds
    
    # Default configuration
    configure do |config|
      config.max_execution_time_ms = 120
      config.fallback_enabled = true
      config.cache_ttl_seconds = 300
    end
    
    def self.execute_for_user(user_id, page, context = {})
      new(user_id, page, context).execute
    end
    
    def initialize(user_id, page, context = {})
      @user_id = user_id
      @page = page
      @context = context
      @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
    
    def execute
      # Get active playbook
      playbook = get_active_playbook
      return execute_fallback unless playbook
      
      # Execute playbook modules
      executed_modules = execute_playbook_modules(playbook)
      
      # Apply placement optimization
      optimized_layout = optimize_placement(executed_modules, playbook)
      
      # Build response
      build_response(optimized_layout, playbook)
      
    rescue => e
      Rails.logger.error "Playbook execution failed: #{e.message}"
      execute_fallback
    end
    
    private
    
    def get_active_playbook
      # Try user-specific playbook first
      if @user_id.present?
        playbook = Playbook.find_active_for_user_and_page(@user_id, @page)
        return playbook if playbook
      end
      
      # Try cohort-based playbook
      cohort_id = determine_cohort_id
      if cohort_id.present?
        playbook = Playbook.find_active_for_cohort_and_page(cohort_id, @page)
        return playbook if playbook
      end
      
      # Try page-level default playbook
      Playbook.find_active_for_cohort_and_page("default_#{@page}", @page)
    end
    
    def determine_cohort_id
      # Pragmatic cohorting based on region, tenure, value tier, pickup mode, and top category
      return nil unless @user_id.present?
      
      user = User.find_by(id: @user_id)
      return nil unless user
      
      region = (@context[:region].presence || 'ke').to_s.downcase
      tenure = user.created_at && user.created_at >= 30.days.ago ? 'new' : 'repeat'
      
      avg_order_value = begin
        user.orders.where.not(total_amount: nil).average(:total_amount).to_f
      rescue
        0.0
      end
      value_tier = if avg_order_value <= 20
        'low'
      elsif avg_order_value <= 100
        'mid'
      else
        'high'
      end
      
      pickup = @context[:pickup_only] ? 'pickup' : 'ship'
      
      # Derive top category preference from orders and wishlist
      top_category_slug = begin
        category_ids = []
        category_ids.concat(
          user.orders.joins(:products).pluck('products.category_id').compact
        )
        category_ids.concat(
          user.wishlist_items.joins(:product).pluck('products.category_id').compact
        )
        top_category_id = category_ids.tally.max_by { |_, c| c }&.first
        if top_category_id
          Category.find_by(id: top_category_id)&.name.to_s.parameterize.presence
        end
      rescue
        nil
      end
      category_segment = top_category_slug || 'general'
      
      [
        'cohort',
        region,
        tenure,
        value_tier,
        pickup,
        category_segment
      ].join(':')
    end
    
    def execute_playbook_modules(playbook)
      modules = playbook.content['modules'] || {}
      thresholds = playbook.content['thresholds'] || {}
      caps = playbook.content['caps'] || {}
      
      executed_modules = []
      
      # Execute each module according to priority
      priority_order = playbook.content['priority'] || modules.keys
      
      priority_order.each do |module_id|
        break if executed_modules.length >= get_max_modules_for_page
        
        module_config = modules[module_id]
        next unless module_config
        
        # Check if module should be executed based on thresholds
        next unless should_execute_module(module_id, module_config, thresholds, caps)
        
        # Execute module
        module_result = execute_module(module_id, module_config)
        next unless module_result&.any?
        
        # Apply caps and filters
        filtered_result = apply_module_caps(module_result, module_id, caps)
        next unless filtered_result&.any?
        
        executed_modules << {
          id: module_id,
          type: determine_module_type(module_id),
          items: filtered_result,
          placement: determine_placement(module_id, executed_modules.length),
          metadata: build_module_metadata(module_id, module_config)
        }
      end
      
      executed_modules
    end
    
    def should_execute_module(module_id, module_config, thresholds, caps)
      # Check minimum items threshold
      min_items = thresholds['min_items'] || 3
      return false if get_estimated_item_count(module_config) < min_items
      
      # Check page-specific conditions
      case @page
      when 'checkout'
        # Only show add-ons if cart has items
        return false if module_id.include?('addon') && !has_cart_items?
      when 'wishlist'
        # Only show price drops if user has saved items
        return false if module_id.include?('price_drop') && !has_saved_items?
      when 'pdp'
        # Only show complements if current product exists
        return false if module_id.include?('complete') && !has_current_product?
      end
      
      true
    end
    
    def execute_module(module_id, module_config)
      algorithm = module_config['algorithm']
      filters = module_config['filters'] || {}
      constraints = module_config['constraints'] || {}
      
      # Convert AI filters to Rails-compatible format
      rails_filters = convert_ai_filters_to_rails(filters)
      
      # Execute based on algorithm
      case algorithm
      when 'trending'
        execute_trending_retrieval(rails_filters, module_config)
      when 'similarity'
        execute_similarity_retrieval(rails_filters, module_config)
      when 'complementary'
        execute_complementary_retrieval(rails_filters, module_config)
      when 'diversity'
        execute_diversity_retrieval(rails_filters, module_config)
      when 'completion'
        execute_completion_retrieval(rails_filters, module_config)
      else
        execute_default_retrieval(rails_filters, module_config)
      end
      
    rescue => e
      Rails.logger.warn "Module execution failed for #{module_id}: #{e.message}"
      []
    end
    
    def convert_ai_filters_to_rails(ai_filters)
      rails_filters = {}
      
      # Convert brand names to brand IDs
      if ai_filters['brand']
        brand = Brand.find_by(name: ai_filters['brand'])
        rails_filters[:brand_id] = brand&.id
      end
      
      # Convert category names to category IDs
      if ai_filters['category']
        category = Category.find_by(name: ai_filters['category'])
        rails_filters[:category_id] = category&.id
      end
      
      # Convert reference product names to IDs
      if ai_filters['reference_product']
        product = Product.find_by(name: ai_filters['reference_product'])
        rails_filters[:reference_product_id] = product&.id
      end
      
      # Handle excluded products
      if ai_filters['excluded_products']&.is_a?(Array)
        excluded_ids = ai_filters['excluded_products'].map do |product_name|
          Product.find_by(name: product_name)&.id
        end.compact
        rails_filters[:excluded_product_ids] = excluded_ids
      end
      
      # Handle search terms
      if ai_filters['search_terms']&.is_a?(Array)
        rails_filters[:search_term] = ai_filters['search_terms'].join(' ')
      end
      
      # Handle price ranges
      if ai_filters['price_range']&.is_a?(Array)
        rails_filters[:price_min] = ai_filters['price_range'][0]
        rails_filters[:price_max] = ai_filters['price_range'][1]
      end
      
      # Pass through other filters
      rails_filters.merge!(ai_filters.except('brand', 'category', 'reference_product', 'excluded_products', 'search_terms', 'price_range'))
      
      rails_filters
    end
    
    def execute_trending_retrieval(filters, module_config)
      knobs = { limit: get_module_limit(module_config) }
      Personalization::Retrieval::Trending.run(filters, knobs, build_retrieval_context).map { |i| i[:id] }
    end
    
    def execute_similarity_retrieval(filters, module_config)
      knobs = { limit: get_module_limit(module_config) }
      Personalization::Retrieval::Lookalikes.run(filters, knobs, build_retrieval_context).map { |i| i[:id] }
    end
    
    def execute_complementary_retrieval(filters, module_config)
      knobs = { limit: get_module_limit(module_config) }
      Personalization::Retrieval::SearchFusion.run(filters, knobs, build_retrieval_context).map { |i| i[:id] }
    end
    
    def execute_diversity_retrieval(filters, module_config)
      knobs = { limit: get_module_limit(module_config), lambda_diversity: 0.7 }
      Personalization::Retrieval::SearchFusion.run(filters, knobs, build_retrieval_context).map { |i| i[:id] }
    end
    
    def execute_completion_retrieval(filters, module_config)
      completion_service = Personalization::Retrieval::UseCaseCompletion.new(
        section_config: { filters: filters, count: get_module_limit(module_config) },
        snapshot: build_snapshot,
        profile: build_profile,
        session_embed_summary: {}
      )
      
      completion_service.run
    end
    
    def execute_default_retrieval(filters, module_config)
      knobs = { limit: get_module_limit(module_config) }
      Personalization::Retrieval::SearchFusion.run(filters, knobs, build_retrieval_context).map { |i| i[:id] }
    end
    
    def build_retrieval_context
      {
        region: @context[:region] || 'ke',
        pickup_only: @context[:pickup_only] || false,
        profile: build_profile
      }
    end
    
    def build_snapshot
      {
        user_id: @user_id,
        session_id: @context[:session_id],
        page: @page,
        region: @context[:region] || 'ke',
        pickup_only: @context[:pickup_only] || false
      }
    end
    
    def build_profile
      return {} unless @user_id.present?
      
      # Build user profile for retrieval context
      {
        user_id: @user_id,
        price_band: extract_user_price_band,
        preferred_categories: extract_preferred_categories,
        preferred_brands: extract_preferred_brands
      }
    end
    
    def get_module_limit(module_config)
      # Determine appropriate limit based on module type and page
      base_limit = case @page
                   when 'home' then 24
                   when 'pdp' then 12
                   when 'wishlist' then 16
                   when 'checkout' then 8
                   when 'profile' then 20
                   else 12
                   end
      
      # Adjust based on module type
      if module_config['algorithm'] == 'trending'
        base_limit = [base_limit, 20].min
      elsif module_config['algorithm'] == 'complementary'
        base_limit = [base_limit, 8].min
      end
      
      base_limit
    end
    
    def apply_module_caps(module_result, module_id, caps)
      return module_result unless module_result&.any?
      
      # Apply item count caps
      max_items = get_max_items_for_module(module_id, caps)
      module_result.first(max_items)
    end
    
    def get_max_items_for_module(module_id, caps)
      case module_id
      when /trending/
        caps['max_trending_items'] || 20
      when /complementary|complete/
        caps['max_complementary_items'] || 8
      when /similar/
        caps['max_similar_items'] || 12
      when /addon/
        caps['max_addon_items'] || 5
      else
        caps['max_items'] || 12
      end
    end
    
    def determine_module_type(module_id)
      case module_id
      when /trending/
        'trending'
      when /similar|lookalike/
        'similar'
      when /complementary|complete/
        'complementary'
      when /diversity|discovery/
        'discovery'
      when /addon/
        'addon'
      when /bundle/
        'bundle'
      else
        'default'
      end
    end
    
    def determine_placement(module_id, position)
      case @page
      when 'home'
        if module_id.include?('trending')
          'home_top'
        elsif module_id.include?('discovery')
          'home_discovery'
        else
          "home_injection_#{position}"
        end
      when 'pdp'
        if module_id.include?('complete')
          'pdp_below_gallery'
        elsif module_id.include?('similar')
          'pdp_below_details'
        else
          'pdp_injection'
        end
      when 'wishlist'
        if module_id.include?('price_drop')
          'wishlist_above_grid'
        elsif module_id.include?('complete')
          'wishlist_after_row_1'
        else
          'wishlist_below_grid'
        end
      when 'checkout'
        if module_id.include?('addon')
          'checkout_below_order'
        elsif module_id.include?('bundle')
          'checkout_below_addon'
        else
          'checkout_injection'
        end
      when 'profile'
        case position
        when 0 then 'profile_top'
        when 1 then 'profile_mid_1'
        when 2 then 'profile_mid_2'
        else 'profile_bottom'
        end
      else
        "default_#{position}"
      end
    end
    
    def optimize_placement(executed_modules, playbook)
      # Apply page-specific placement optimization
      case @page
      when 'home'
        optimize_home_placement(executed_modules)
      when 'pdp'
        optimize_pdp_placement(executed_modules)
      when 'wishlist'
        optimize_wishlist_placement(executed_modules)
      when 'checkout'
        optimize_checkout_placement(executed_modules)
      when 'profile'
        optimize_profile_placement(executed_modules)
      else
        executed_modules
      end
    end
    
    def optimize_home_placement(modules)
      # Home page: trending strip at top, discovery grid, then injections
      trending = modules.find { |m| m[:placement] == 'home_top' }
      discovery = modules.find { |m| m[:placement] == 'home_discovery' }
      injections = modules.select { |m| m[:placement].start_with?('home_injection') }
      
      [trending, discovery, *injections].compact
    end
    
    def optimize_pdp_placement(modules)
      # PDP: complements first, then similar items, then optional injection
      complements = modules.find { |m| m[:placement] == 'pdp_below_gallery' }
      similar = modules.find { |m| m[:placement] == 'pdp_below_details' }
      injection = modules.find { |m| m[:placement] == 'pdp_injection' }
      
      [complements, similar, injection].compact
    end
    
    def optimize_wishlist_placement(modules)
      # Wishlist: price drops first, then complements, then similar
      price_drops = modules.find { |m| m[:placement] == 'wishlist_above_grid' }
      complements = modules.find { |m| m[:placement] == 'wishlist_after_row_1' }
      similar = modules.find { |m| m[:placement] == 'wishlist_below_grid' }
      
      [price_drops, complements, similar].compact
    end
    
    def optimize_checkout_placement(modules)
      # Checkout: add-ons first, then bundle upgrade
      addons = modules.find { |m| m[:placement] == 'checkout_below_order' }
      bundle = modules.find { |m| m[:placement] == 'checkout_below_addon' }
      
      [addons, bundle].compact
    end
    
    def optimize_profile_placement(modules)
      # Profile: maintain priority order
      modules.sort_by { |m| m[:placement] }
    end
    
    def build_response(optimized_modules, playbook)
      {
        page: @page,
        playbook_id: playbook.playbook_id,
        modules: optimized_modules.map do |module_data|
          {
            id: module_data[:id],
            type: module_data[:type],
            placement: module_data[:placement],
            items: module_data[:items],
            metadata: module_data[:metadata]
          }
        end,
        metadata: {
          ai_generated: playbook.ai_generated,
          generated_at: playbook.generated_at.iso8601,
          expires_at: playbook.expires_at.iso8601,
          execution_time_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_time) * 1000).round(2)
        }
      }
    end
    
    def execute_fallback
      Rails.logger.info "Executing fallback for #{@page}"
      
      # Build basic fallback response
      {
        page: @page,
        playbook_id: "fallback_#{@page}_#{Time.current.to_i}",
        modules: build_fallback_modules,
        metadata: {
          ai_generated: false,
          fallback: true,
          execution_time_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_time) * 1000).round(2)
        }
      }
    end
    
    def build_fallback_modules
      case @page
      when 'home'
        [
          {
            id: 'trending_near_you',
            type: 'trending',
            placement: 'home_top',
            items: execute_trending_retrieval({ region: @context[:region] || 'ke' }, {}),
            metadata: { reason: 'fallback_trending' }
          }
        ]
      when 'pdp'
        [
          {
            id: 'similar_items',
            type: 'similar',
            placement: 'pdp_below_details',
            items: execute_similarity_retrieval({}, {}),
            metadata: { reason: 'fallback_similar' }
          }
        ]
      else
        []
      end
    end
    
    # Helper methods for module execution conditions
    def has_cart_items?
      return false unless @user_id.present?
      CartItem.where(user_id: @user_id).exists?
    end
    
    def has_saved_items?
      return false unless @user_id.present?
      WishlistItem.where(user_id: @user_id).exists?
    end
    
    def has_current_product?
      @context[:product_id].present?
    end
    
    def get_estimated_item_count(module_config)
      # Estimate item count based on module configuration
      case module_config['algorithm']
      when 'trending'
        15
      when 'similarity'
        10
      when 'complementary'
        6
      when 'diversity'
        12
      else
        8
      end
    end
    
    def get_max_modules_for_page
      case @page
      when 'home' then 6
      when 'pdp' then 3
      when 'wishlist' then 4
      when 'checkout' then 2
      when 'profile' then 4
      else 3
      end
    end
    
    def extract_user_price_band
      return nil unless @user_id.present?
      
      # Extract user's typical price range from recent orders/views
      # This would be implemented based on your data
      { min: 50, max: 200 }
    end
    
    def extract_preferred_categories
      return [] unless @user_id.present?
      
      # Extract user's preferred categories from behavior
      # This would be implemented based on your data
      []
    end
    
    def extract_preferred_brands
      return [] unless @user_id.present?
      
      # Extract user's preferred brands from behavior
      # This would be implemented based on your data
      []
    end
  end
end

