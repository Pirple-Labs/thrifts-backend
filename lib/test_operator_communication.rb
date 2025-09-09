#!/usr/bin/env ruby

# Test script to demonstrate Rails-Operator communication
puts "🔗 Testing Rails-Operator Communication"
puts "=" * 50

# Set up environment
ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
ENV['OPERATOR_TIMEOUT_MS'] = '700'
ENV['PERSONALIZATION_JWT_SECRET'] = Rails.application.secret_key_base
ENV['ENABLE_OPERATOR'] = 'true'

puts "⚙️  Environment configured:"
puts "   Operator URL: #{ENV['PERSONALIZATION_OPERATOR_URL']}"
puts "   Timeout: #{ENV['OPERATOR_TIMEOUT_MS']}ms"
puts "   Operator Enabled: #{ENV['ENABLE_OPERATOR']}"
puts ""

# Create mock request and session objects
request = OpenStruct.new(
  user_id: 1,
  session_id: "test_session_#{SecureRandom.hex(4)}",
  page: "home",
  pid: nil,
  region: "ke",
  geohash6: nil,
  pickup_only: false
)

session = OpenStruct.new(
  id: request.session_id,
  user_id: request.user_id
)

puts "📊 Test Parameters:"
puts "   Page: #{request.page}"
puts "   User ID: #{request.user_id}"
puts "   Session ID: #{request.session_id}"
puts "   Region: #{request.region}"
puts "   Pickup Only: #{request.pickup_only}"
puts ""

# Build snapshot
puts "🔍 Step 1: Building Snapshot..."
snapshot = Personalization::SnapshotBuilder.build(request, session)
puts "   Snapshot built successfully"
puts "   Region: #{snapshot[:region]}"
puts "   Views 10m: #{snapshot[:views_10m]&.count || 0}"
puts "   Inactivity: #{snapshot[:inactivity_bucket]}"
puts ""

# Build profile
puts "👤 Step 2: Building Profile..."
profile = Personalization::ProfileStore.slice(request.user_id)
puts "   Profile built successfully"
puts "   Price Band: #{profile[:price_band]}"
puts "   Top Categories: #{profile[:top_categories]}"
puts ""

# Build session embedding summary
session_embed_summary = {
  topics: ["test", "communication"],
  centroid_bucket: "test-bkt-01"
}

# Get profile hash
profile_hash = Personalization::ProfileHasher.hash(snapshot, profile)
puts "🔑 Step 3: Profile Hash: #{profile_hash}"
puts ""

# Check for intent drift
intent_drift = Personalization::IntentEngine.drift?(snapshot, snapshot, profile)
puts "🎯 Step 4: Intent Drift: #{intent_drift}"
puts ""

# Try to get plan from cache first
puts "💾 Step 5: Checking Plan Cache..."
plan = Personalization::PlanCache.get(request.page, profile_hash)
if plan
  puts "   ✅ Cache HIT! Using cached plan: #{plan[:plan_id]}"
else
  puts "   ❌ Cache MISS! Fetching from Operator..."
  puts ""
  
  # Fetch plan from Operator
  puts "📡 Step 6: Sending Request to Operator..."
  puts "   Endpoint: #{ENV['PERSONALIZATION_OPERATOR_URL']}/operator/query-pack"
  puts "   Request ID: #{SecureRandom.uuid}"
  puts ""
  
  constraints = {
    p95_budget_ms: 1000,
    max_sections: 6
  }
  
  begin
    plan = Personalization::PlannerClient.fetch_plan(
      page: request.page,
      snapshot: snapshot,
      profile: profile,
      session_embed_summary: session_embed_summary,
      constraints: constraints
    )
    
    puts "✅ Step 7: Operator Response Received!"
    puts "   Plan ID: #{plan[:plan_id]}"
    puts "   Source: #{plan[:source]}"
    puts "   TTL: #{plan[:ttl_seconds]} seconds"
    puts "   Sections: #{plan[:sections]&.count || 0}"
    puts ""
    
    # Show section details
    if plan[:sections]
      puts "📋 Section Details:"
      plan[:sections].each_with_index do |section, index|
        puts "   #{index + 1}. #{section[:id]} (#{section[:count]} items)"
        puts "      Reason: #{section[:reason]}"
        puts "      Filters: #{section[:filters]}"
      end
      puts ""
    end
    
    # Store plan in cache
    puts "💾 Step 8: Storing Plan in Cache..."
    Personalization::PlanCache.set(request.page, profile_hash, plan, ttl: plan[:ttl_seconds] || 172800)
    puts "   Plan cached successfully"
    puts ""
    
  rescue => e
    puts "❌ Step 7: Operator Request Failed!"
    puts "   Error: #{e.message}"
    puts "   Falling back to control plan..."
    puts ""
    
    plan = Personalization::PlannerClient.control_plan(request.page)
    puts "   Control plan generated: #{plan[:plan_id]}"
    puts ""
  end
end

# Execute plan sections
puts "⚙️  Step 9: Executing Plan Sections..."
sections = []
merchant_counts = {}

plan[:sections].each do |section_config|
  puts "   Processing section: #{section_config[:id]}"
  
  # Execute section retrieval
  candidates = case section_config[:id]
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
  
  puts "     Candidates: #{candidates.length}"
  
  # Apply guardrails
  guardrails_result = Personalization::Guardrails.apply(
    candidates, 
    {
      snapshot: snapshot,
      profile: profile,
      merchant_counts: merchant_counts
    }
  )
  
  puts "     After guardrails: #{guardrails_result[:filtered].length}"
  
  # Apply coordination if applicable
  coordinated_items = Personalization::Coordination.fill_if_applicable(
    guardrails_result[:filtered],
    section_config,
    snapshot,
    profile
  )
  
  puts "     After coordination: #{coordinated_items.length}"
  
  # Take requested count
  final_items = coordinated_items.take(section_config[:count])
  puts "     Final items: #{final_items.length}"
  
  # Update merchant counts
  final_items.each do |item|
    product = Product.find_by(id: item[:id])
    next unless product
    merchant_counts[product.shop_id] = (merchant_counts[product.shop_id] || 0) + 1
  end
  
  sections << {
    id: section_config[:id],
    count: final_items.length,
    reason: section_config[:reason]
  }
end

puts ""
puts "📊 Final Results:"
puts "   Total Sections: #{sections.count}"
puts "   Total Products: #{sections.sum { |s| s[:count] }}"
puts "   Plan Source: #{plan[:source]}"
puts ""

puts "🎉 Rails-Operator Communication Test Complete!"
puts "=" * 50

