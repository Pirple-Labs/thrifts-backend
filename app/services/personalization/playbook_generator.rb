# app/services/personalization/playbook_generator.rb
# frozen_string_literal: true

module Personalization
  class PlaybookGenerator
    include ActiveSupport::Configurable
    
    # Configuration
    config_accessor :ai_service_url, :ai_timeout_seconds, :max_retries, :default_ttl_hours
    config_accessor :cohort_threshold, :fallback_playbook_enabled
    
    # Default configuration
    configure do |config|
      config.ai_service_url = ENV['AI_SERVICE_URL'] || 'http://localhost:8000'
      config.ai_timeout_seconds = 30
      config.max_retries = 2
      config.default_ttl_hours = 48
      config.cohort_threshold = 100 # Minimum users for cohort-based playbooks
      config.fallback_playbook_enabled = true
    end
    
    DEFAULT_PAGES = %w[home pdp wishlist checkout profile].freeze

    def self.generate_for_user(user_id, page, user_context = {})
      new(user_id, page, user_context).generate
    end
    
    def self.generate_for_cohort(cohort_id, page, cohort_context = {})
      new(nil, page, cohort_context, cohort_id: cohort_id).generate
    end

    def self.generate_for_user_multi_page(user_id, pages = DEFAULT_PAGES, user_context = {})
      new(user_id, 'multi', user_context).generate_multi_page(pages)
    end
    
    def initialize(user_id, page, context = {}, cohort_id: nil)
      @user_id = user_id
      @cohort_id = cohort_id
      @page = page
      @context = context
      @playbook_id = Playbook.generate_playbook_id(user_id, page)
    end
    
    def generate
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      
      begin
        # Check if we should use cohort-based generation
        if should_use_cohort?
          generate_cohort_playbook
        else
          generate_user_playbook
        end
        
      rescue => e
        Rails.logger.error "Playbook generation failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        # Fallback to control playbook
        generate_fallback_playbook
      ensure
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        track_generation_metrics(duration_ms)
      end
    end

    def generate_multi_page(pages)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      pages = (pages.presence || DEFAULT_PAGES)

      begin
        payload = build_ai_payload.merge(
          ai_instructions: build_ai_instructions_multi(pages)
        )

        ai_response = call_ai_service(payload)

        # Expect canonical multi-page layout: content.page_plans
        page_plans = ai_response.dig('content', 'page_plans')

        if page_plans.is_a?(Hash)
          stored = {}
          pages.each do |page|
            per_page_content = page_plans[page]
            # Fallback: if a specific page is missing, try a generic content or empty
            per_page_content ||= ai_response['content'] if ai_response.dig('content', 'modules')
            per_page_content ||= { 'modules' => {}, 'priority' => [], 'thresholds' => { 'min_items' => 3 }, 'caps' => {} }
            stored[page] = store_playbook_for_page(page, per_page_content, ai_response)
          end
          stored
        else
          # Back-compat: operator returned single-page content; fan-out same content to all pages
          content = validate_and_process_ai_response(ai_response)
          pages.each_with_object({}) do |page, acc|
            acc[page] = store_playbook_for_page(page, content, ai_response)
          end
        end
      rescue => e
        Rails.logger.error "Multi-page playbook generation failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        # Store fallbacks for each page if enabled
        pages.each_with_object({}) do |page, acc|
          @page = page
          acc[page] = store_playbook_for_page(page, build_fallback_playbook, nil, ai_generated: false)
        end
      ensure
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        track_generation_metrics(duration_ms)
      end
    end
    
    private
    
    def should_use_cohort?
      return false if @user_id.present?
      return true if @cohort_id.present?
      
      # Check if user count in cohort is above threshold
      user_count = get_cohort_user_count
      user_count >= cohort_threshold
    end
    
    def generate_user_playbook
      # Build AI request payload
      ai_payload = build_ai_payload
      
      # Call AI service
      ai_response = call_ai_service(ai_payload)
      
      # Validate and process AI response
      playbook_content = validate_and_process_ai_response(ai_response)
      
      # Store playbook
      store_playbook(playbook_content, ai_response)
    end
    
    def generate_cohort_playbook
      # Similar to user playbook but with cohort context
      ai_payload = build_cohort_ai_payload
      ai_response = call_ai_service(ai_payload)
      playbook_content = validate_and_process_ai_response(ai_response)
      store_playbook(playbook_content, ai_response, cohort_id: @cohort_id)
    end
    
    def generate_fallback_playbook
      Rails.logger.info "Generating fallback playbook for #{@playbook_id}"
      
      fallback_content = build_fallback_playbook
      store_playbook(fallback_content, nil, ai_generated: false)
    end
    
    def build_ai_payload
      {
        user_context: build_user_context,
        profile: build_profile_for_ai,
        session_embed_summary: build_session_embed_summary,
        ai_instructions: build_ai_instructions,
        allowed_vocabulary: build_allowed_vocabulary,
        page_context: build_page_context
      }
    end
    
    def build_cohort_ai_payload
      {
        cohort_context: build_cohort_context,
        ai_instructions: build_ai_instructions,
        page_context: build_page_context
      }
    end
    
    def build_user_context
      base_context = {
        user_id: @user_id,
        page: @page,
        timestamp: Time.current.iso8601,
        region: @context[:region] || "ke"
      }
      
      # Add behavioral data if available
      if @user_id.present?
        base_context.merge!(extract_user_behavioral_data)
      end
      
      base_context
    end

    def build_profile_for_ai
      return {} unless @user_id.present?
      begin
        profile = Personalization::ProfileStore.slice(@user_id) || {}
        {
          user_id: @user_id,
          price_band: profile[:price_band],
          top_categories: profile[:top_categories],
          top_brands: profile[:top_brands]
        }.compact
      rescue => _e
        {}
      end
    end

    def build_session_embed_summary
      # Placeholder; include if your embedding/session summary is available
      {}
    end
    
    def build_cohort_context
      {
        cohort_id: @cohort_id,
        page: @page,
        timestamp: Time.current.iso8601,
        region: @context[:region] || "ke",
        cohort_size: get_cohort_user_count,
        cohort_characteristics: extract_cohort_characteristics
      }
    end
    
    def build_ai_instructions
      {
        task: 'generate_conversion_playbook',
        requirements: {
          page: @page,
          max_sections: get_max_sections_for_page,
          conversion_optimized: true,
          reusable_sections: true,
          search_strategies: true,
          placement_suggestions: true
        }
      }
    end

    def build_ai_instructions_multi(pages)
      {
        task: 'generate_conversion_playbook',
        requirements: {
          pages: pages,
          max_sections_per_page: 6,
          conversion_optimized: true,
          reusable_sections: true,
          search_strategies: true,
          placement_suggestions: true
        }
      }
    end
    
    def build_page_context
      case @page
      when 'home'
        {
          layout: 'discovery_heavy',
          structure: 'trending_strip + discovery_grid + dynamic_injections',
          focus: 'discovery and personalization'
        }
      when 'pdp'
        {
          layout: 'product_focused',
          structure: 'complements_strip + similar_grid + optional_injection',
          focus: 'conversion and complementary discovery'
        }
      when 'wishlist'
        {
          layout: 'saved_items_focused',
          structure: 'saved_grid + price_alerts + complements + similar',
          focus: 'reactivation and completion'
        }
      when 'checkout'
        {
          layout: 'conversion_focused',
          structure: 'order_summary + compact_addons + bundle_upgrade',
          focus: 'AOV lift without distraction'
        }
      when 'profile'
        {
          layout: 'identity_focused',
          structure: 'picks_today + new_from_brands + continue_browsing + exploration',
          focus: 'identity-based personalization'
        }
      else
        {}
      end
    end
    
    def call_ai_service(payload)
      headers = {
        'Content-Type' => 'application/json',
        'X-Plan-DSL-Version' => '3.0',
        'X-Request-Id' => "playbook_#{@playbook_id}_#{Time.current.to_i}"
      }
      
      response = HTTParty.post(
        "#{ai_service_url}/operator/query-pack",
        body: payload.to_json,
        headers: headers,
        timeout: ai_timeout_seconds
      )
      
      if response.success?
        response.parsed_response
      else
        raise "AI service error: #{response.code} - #{response.body}"
      end
    end
    
    def validate_and_process_ai_response(ai_response)
      return build_fallback_playbook unless ai_response
      
      # Accept canonical content.modules format directly
      if ai_response['content'].is_a?(Hash) && ai_response['content']['modules'].is_a?(Hash)
        # Store exactly as provided by the operator, unmodified
        return ai_response['content']
      end
      
      # Back-compat: personalized_sections array
      unless ai_response['personalized_sections']&.is_a?(Array)
        Rails.logger.warn "Invalid AI response structure for #{@playbook_id}"
        return build_fallback_playbook
      end
      
      processed_sections = ai_response['personalized_sections'].map { |section| validate_and_process_section(section) }.compact
      
      {
        page: @page,
        modules: build_module_definitions(processed_sections),
        thresholds: build_thresholds(processed_sections),
        caps: build_caps_for_page,
        priority: build_priority_rules(processed_sections)
      }
    end

    # Build a compact vocabulary to ground AI search_terms
    def build_allowed_vocabulary
      brands = Brand.limit(50).pluck(:name).compact
      categories = Category.limit(50).pluck(:name).compact
      colors = Product.where.not(color: nil).limit(50).pluck(:color).compact.uniq
      families = Product.where.not(name: nil).limit(200).pluck(:name).map { |n| n.split.first(3).join(' ') }.uniq.first(100)
      {
        brands: brands,
        categories: categories,
        colors: colors,
        product_families: families
      }
    rescue
      {}
    end

    # Note: We intentionally do not sanitize or alter AI-provided content.
    
    def validate_and_process_section(section)
      required_fields = %w[id title type conversion_potential search_strategy]
      missing_fields = required_fields - section.keys
      
      if missing_fields.any?
        Rails.logger.warn "Section missing required fields: #{missing_fields.join(', ')}"
        return nil
      end
      
      # Validate search strategy
      search_strategy = section['search_strategy']
      unless search_strategy&.dig('algorithm') && search_strategy&.dig('filters')
        Rails.logger.warn "Invalid search strategy for section #{section['id']}"
        return nil
      end
      
      section
    end
    
    def build_module_definitions(sections)
      sections.each_with_object({}) do |section, modules|
        modules[section['id']] = {
          algorithm: section['search_strategy']['algorithm'],
          filters: section['search_strategy']['filters'],
          constraints: section['search_strategy']['constraints'] || {},
          time_window: section['search_strategy']['time_window']
        }
      end
    end
    
    def build_thresholds(sections)
      {
        inject_min_score: 0.55,
        min_items: 5,
        max_price_drop_pct: 0.1,
        min_complements: 5
      }
    end
    
    def build_caps_for_page
      case @page
      when 'home'
        { max_injections: 5, min_rows_between: 3 }
      when 'pdp'
        { max_injections: 1, min_items: 5 }
      when 'wishlist'
        { max_modules: 2, min_items: 3 }
      when 'checkout'
        { max_modules: 2, max_addon_price: 20 }
      when 'profile'
        { max_modules: 4, min_items: 5 }
      else
        { max_injections: 3, min_items: 5 }
      end
    end
    
    def build_priority_rules(sections)
      sections.map { |s| s['id'] }
    end
    
    def build_fallback_playbook
      {
        page: @page,
        modules: build_fallback_modules,
        thresholds: { inject_min_score: 0.5, min_items: 3 },
        caps: { max_injections: 2, min_items: 3 },
        priority: build_fallback_priority
      }
    end
    
    def build_fallback_modules
      case @page
      when 'home'
        {
          'trending_near_you' => {
            algorithm: 'trending',
            filters: { region: @context[:region] || 'ke' },
            time_window: '7d'
          },
          'discovery_grid' => {
            algorithm: 'diversity',
            filters: { diversity_boost: true }
          }
        }
      when 'pdp'
        {
          'complete_the_look' => {
            algorithm: 'complementary',
            constraints: { attach_rate_min: 0.08 }
          },
          'similar_items' => {
            algorithm: 'similarity',
            constraints: { style_match: true, price_band_pct: 0.2 }
          }
        }
      else
        {
          'default_section' => {
            algorithm: 'trending',
            filters: { region: @context[:region] || 'ke' }
          }
        }
      end
    end
    
    def build_fallback_priority
      case @page
      when 'home'
        %w[trending_near_you discovery_grid]
      when 'pdp'
        %w[complete_the_look similar_items]
      else
        %w[default_section]
      end
    end
    
    def store_playbook(content, ai_response = nil, ai_generated: true, cohort_id: nil)
      meta = ai_response&.[]("ai_metadata") || ai_response&.[]("metadata") || {}
      playbook = Playbook.create!(
        playbook_id: @playbook_id,
        user_id: @user_id,
        cohort_id: cohort_id,
        page: @page,
        valid_for_hours: default_ttl_hours,
        generated_at: Time.current,
        ai_generated: ai_generated,
        content: content,
        user_context: @context,
        ai_instructions: build_ai_instructions,
        ai_model_version: meta['model_version'],
        ai_prompt_version: meta['prompt_version'],
        generation_cost_usd: meta['cost_usd'],
        generation_duration_ms: meta['duration_ms'],
        generation_log: build_generation_log(ai_response)
      )
      
      Rails.logger.info "Stored playbook #{@playbook_id} for #{@page} (#{ai_generated ? 'AI' : 'fallback'})"
      playbook
    end

    def store_playbook_for_page(page, content, ai_response = nil, ai_generated: true, cohort_id: nil)
      per_page_playbook_id = Playbook.generate_playbook_id(@user_id, page)
      meta = ai_response&.[]("ai_metadata") || ai_response&.[]("metadata") || {}

      Playbook.create!(
        playbook_id: per_page_playbook_id,
        user_id: @user_id,
        cohort_id: cohort_id,
        page: page,
        valid_for_hours: default_ttl_hours,
        generated_at: Time.current,
        ai_generated: ai_generated,
        content: content,
        user_context: @context,
        ai_instructions: build_ai_instructions,
        ai_model_version: meta['model_version'],
        ai_prompt_version: meta['prompt_version'],
        generation_cost_usd: meta['cost_usd'],
        generation_duration_ms: meta['duration_ms'],
        generation_log: build_generation_log(ai_response)
      )
    end
    
    def build_generation_log(ai_response)
      {
        timestamp: Time.current.iso8601,
        user_id: @user_id,
        cohort_id: @cohort_id,
        page: @page,
        ai_response_present: ai_response.present?,
        sections_count: ai_response&.dig('personalized_sections')&.length || 0,
        fallback_used: ai_response.blank?
      }
    end
    
    def extract_user_behavioral_data
      return {} unless @user_id.present?
      
      # Extract recent behavioral patterns
      recent_events = Event.where(user_id: @user_id)
                          .where(timestamp_utc: 7.days.ago..)
                          .order(:timestamp_utc)
                          .limit(100)
      
      {
        behavioral_patterns: analyze_behavioral_patterns(recent_events),
        micro_events: extract_micro_events(recent_events),
        meso_events: extract_meso_events(recent_events),
        macro_events: extract_macro_events(recent_events)
      }
    end
    
    def extract_cohort_characteristics
      return {} unless @cohort_id.present?
      
      # Extract cohort-level characteristics
      {
        avg_session_duration: 0,
        top_categories: [],
        top_brands: [],
        avg_order_value: 0
      }
    end
    
    def get_cohort_user_count
      # This would be implemented based on your cohort definition
      # For now, return a placeholder
      0
    end
    
    def get_max_sections_for_page
      case @page
      when 'home' then 6
      when 'pdp' then 3
      when 'wishlist' then 4
      when 'checkout' then 2
      when 'profile' then 4
      else 3
      end
    end
    
    def analyze_behavioral_patterns(events)
      # Analyze events to extract behavioral patterns
      {
        search_to_browse: false,
        category_hopping: false,
        price_exploration: false,
        brand_loyalty: 0.3,
        engagement_velocity: 1.0
      }
    end
    
    def extract_micro_events(events)
      # Extract micro events (last 5 minutes)
      raw = events.where(timestamp_utc: 5.minutes.ago..)
                  .order(:timestamp_utc)
                  .limit(10)
                  .map { |e| format_event_for_ai(e) }
      raw.compact
    end
    
    def extract_meso_events(events)
      # Extract meso events (last hour)
      raw = events.where(timestamp_utc: 1.hour.ago..)
                  .order(:timestamp_utc)
                  .limit(20)
                  .map { |e| format_event_for_ai(e) }
      raw.compact
    end
    
    def extract_macro_events(events)
      # Extract macro events (last week)
      raw = events.where(timestamp_utc: 7.days.ago..)
                  .order(:timestamp_utc)
                  .limit(50)
                  .map { |e| format_event_for_ai(e) }
      raw.compact
    end
    
    def format_event_for_ai(event)
      product_id = extract_product_id(event)
      product = Product.find_by(id: product_id) if product_id
      product_meta = if product
        {
          id: product.id,
          name: product.name,
          category_id: product.category_id,
          brand_id: product.brand_id,
          price: product.price,
          sku: (product.respond_to?(:sku) ? product.sku : nil)
        }.compact
      end

      {
        event_type: event.event_name,
        timestamp: event.timestamp_utc.iso8601,
        weight: 1.0,
        context: {
          page: event.payload&.dig('page'),
          position: event.payload&.dig('position'),
          product_id: product_id
        }.compact,
        product: product_meta
      }
    end

    def extract_product_id(event)
      pid = event.payload&.dig('product_id') || event.payload&.dig(:product_id)
      pid.to_i if pid.present?
    end
    
    def track_generation_metrics(duration_ms)
      # Track generation metrics for monitoring
      Personalization::CostMeter.track_playbook_generation!(
        playbook_id: @playbook_id,
        user_id: @user_id,
        page: @page,
        duration_ms: duration_ms,
        ai_generated: true
      )
    rescue => e
      Rails.logger.warn "Failed to track playbook generation metrics: #{e.message}"
    end
  end
end

