# frozen_string_literal: true

# Demo script to show personalized feeds working
class DemoPersonalizedFeeds
  def self.run
    puts "🎯 Personalized Feeds Demo"
    puts "=" * 50
    puts ""
    
    # Set up environment
    setup_environment
    
    # Test different scenarios
    test_scenarios = [
      {
        name: "Home Page - New User",
        params: { page: "home", user_id: 1, region: "ke", pickup_only: false }
      },
      {
        name: "Search Page - Electronics Lover",
        params: { page: "search", user_id: 2, region: "ke", pickup_only: false }
      },
      {
        name: "PDP Page - Fashion Enthusiast",
        params: { page: "pdp", user_id: 3, region: "ke", pickup_only: false }
      },
      {
        name: "Profile Page - Pickup Only User",
        params: { page: "profile", user_id: 4, region: "ke", pickup_only: true }
      }
    ]
    
    test_scenarios.each_with_index do |scenario, index|
      puts "🧪 Test #{index + 1}: #{scenario[:name]}"
      puts "-" * 40
      
      begin
        result = test_personalized_feed(scenario[:params])
        display_results(result)
      rescue => e
        puts "❌ Error: #{e.message}"
        puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
      end
      
      puts ""
      sleep(1) # Brief pause between tests
    end
    
    puts "🎉 Demo completed!"
    puts ""
    puts "💡 Next steps:"
    puts "   1. Start the mock Operator: rails operator:start_mock"
    puts "   2. Test the demo endpoint: curl 'http://localhost:3000/api/demo/personalized-feed?page=home&user_id=1'"
    puts "   3. Check the Rails logs for detailed information"
  end
  
  private
  
  def self.setup_environment
    # Set environment variables for demo
    ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
    ENV['OPERATOR_TIMEOUT_MS'] = '700'
    ENV['PERSONALIZATION_JWT_SECRET'] = Rails.application.secret_key_base
    ENV['ENABLE_OPERATOR'] = 'true'
    
    puts "⚙️  Environment configured for demo"
    puts "   Operator URL: #{ENV['PERSONALIZATION_OPERATOR_URL']}"
    puts "   Timeout: #{ENV['OPERATOR_TIMEOUT_MS']}ms"
    puts "   Operator Enabled: #{ENV['ENABLE_OPERATOR']}"
    puts ""
  end
  
  def self.test_personalized_feed(params)
    # Build snapshot using a mock request object
    request = OpenStruct.new(
      user_id: params[:user_id],
      session_id: "demo_session_#{SecureRandom.hex(4)}",
      page: params[:page],
      pid: params[:pid],
      region: params[:region],
      geohash6: params[:geohash6],
      pickup_only: params[:pickup_only]
    )
    
    session = OpenStruct.new(
      last_search: "",
      recent_views: []
    )
    
    snapshot = Personalization::SnapshotBuilder.build(request, session)
    
    # Build profile
    profile = Personalization::ProfileStore.slice(params[:user_id])
    
    # Build session embedding summary
    session_embed_summary = {
      topics: ["demo", "personalized"],
      centroid_bucket: "demo-bkt-01"
    }
    
    # Get profile hash
    profile_hash = Personalization::ProfileHasher.hash(snapshot, profile)
    
    # Check for intent drift
    intent_drift = Personalization::IntentEngine.drift?(snapshot, snapshot, profile)
    
    # Try to get plan from cache
    plan = Personalization::PlanCache.get(params[:page], profile_hash)
    
    unless plan
      # Fetch plan from Operator (will fallback to control plan if Operator unavailable)
      constraints = {
        p95_budget_ms: 1000,
        max_sections: 6
      }
      
      plan = Personalization::PlannerClient.fetch_plan(
        page: params[:page],
        snapshot: snapshot,
        profile: profile,
        session_embed_summary: session_embed_summary,
        constraints: constraints
      )
      
      # Validate plan
      validation_errors = Personalization::SectionValidator.validate_plan(plan, params[:page])
      if validation_errors.any?
        Rails.logger.error("Plan validation failed: #{validation_errors.join(', ')}")
        plan = Personalization::PlannerClient.control_plan(params[:page])
      end
      
      # Store plan in cache
      Personalization::PlanCache.set(params[:page], profile_hash, plan, ttl: plan[:ttl_seconds] || 172800)
    end
    
    # Execute plan sections
    sections = execute_plan_sections(plan, snapshot, profile, session_embed_summary)
    
    {
      params: params,
      snapshot: snapshot,
      profile: profile,
      profile_hash: profile_hash,
      intent_drift: intent_drift,
      plan: plan,
      sections: sections
    }
  end
  
  def self.execute_plan_sections(plan, snapshot, profile, session_embed_summary)
    sections = []
    merchant_counts = {}
    
    # Handle both old and new plan formats (symbol and string keys)
    plan_sections = plan[:sections] || plan['sections'] || plan.dig(:page_plans, snapshot[:page], :sections) || []
    
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
        retrieval_latency: 0,
        guardrails_latency: 0,
        coordination_latency: 0,
        total_latency: 0
      }
      
      sections << section
    end
    
    sections
  end
  
  def self.retrieve_section_products(section_config, snapshot, profile, session_embed_summary)
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
  
  def self.display_results(result)
    puts "📊 Results:"
    puts "   Page: #{result[:params][:page]}"
    puts "   User ID: #{result[:params][:user_id]}"
    puts "   Region: #{result[:params][:region]}"
    puts "   Pickup Only: #{result[:params][:pickup_only]}"
    puts ""
    
    puts "👤 Profile Analysis:"
    puts "   Price Band: #{result[:profile][:price_band]}"
    puts "   Top Categories: #{result[:profile][:top_categories].join(', ')}"
    puts "   Brand Preferences: #{result[:profile][:brand_top].join(', ')}"
    puts "   Freshness Preference: #{result[:profile][:freshness_pref]}"
    puts "   Diversity Preference: #{result[:profile][:diversity_pref]}"
    puts ""
    
    puts "📋 Plan Details:"
    puts "   Plan ID: #{result[:plan][:plan_id]}"
    puts "   Source: #{result[:plan][:source]}"
    puts "   TTL: #{result[:plan][:ttl_seconds]} seconds"
    puts "   Profile Hash: #{result[:profile_hash]}"
    puts "   Intent Drift: #{result[:intent_drift]}"
    puts ""
    
    puts "📦 Sections Generated:"
    result[:sections].each_with_index do |section, index|
      puts "   #{index + 1}. #{section[:id]} (#{section[:products].count} products)"
      puts "      Reason: #{section[:reason]}"
      puts "      Pre-guard candidates: #{section[:pre_guard_candidates]&.count || 0}"
      puts "      Guardrail drops: #{section[:guardrail_drops]&.values&.sum || 0}"
    end
    
    total_products = result[:sections].sum { |s| s[:products].count }
    puts ""
    puts "📈 Summary:"
    puts "   Total Sections: #{result[:sections].count}"
    puts "   Total Products: #{total_products}"
    puts "   Plan Source: #{result[:plan][:source]}"
  end
end
