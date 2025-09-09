#!/usr/bin/env ruby

puts "🔄 Testing End-to-End Personalization Flow"
puts "=" * 50

# Set up environment to use Operator (test LLM plans)
ENV['ENABLE_OPERATOR'] = 'true'
ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
ENV['OPERATOR_TIMEOUT_MS'] = '700'

puts "⚙️  Environment configured:"
puts "   Operator: ENABLED (using LLM plans)"
puts "   Rails Backend: http://localhost:3000"
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
puts ""

# Build snapshot
puts "🔍 Step 1: Building Snapshot..."
snapshot = Personalization::SnapshotBuilder.build(request, session)
puts "   ✅ Snapshot built successfully"
puts "   Region: #{snapshot[:region]}"
puts "   Views 10m: #{snapshot[:views_10m]&.count || 0}"
puts "   Inactivity: #{snapshot[:inactivity_bucket]}"
puts ""

# Build profile
puts "👤 Step 2: Building Profile..."
profile = Personalization::ProfileStore.slice(request.user_id)
puts "   ✅ Profile built successfully"
puts "   Price Band: #{profile[:price_band]}"
puts "   Top Categories: #{profile[:top_categories]}"
puts ""

# Get profile hash
profile_hash = Personalization::ProfileHasher.hash(snapshot, profile)
puts "🔑 Step 3: Profile Hash: #{profile_hash}"
puts ""

# Check for intent drift
puts "🎯 Step 4: Intent Drift Check..."
drift = Personalization::IntentEngine.drift?(snapshot, snapshot, profile)
puts "   Intent Drift: #{drift}"
puts ""

# Get plan (should use control plan since operator is disabled)
puts "📋 Step 5: Getting Plan..."
plan = Personalization::PlanCache.get(request.page, profile_hash)

if plan
  puts "   ✅ Cache HIT! Using cached plan."
else
  puts "   ❌ Cache MISS! Fetching from Operator..."
  plan = Personalization::PlannerClient.fetch_plan(
    page: request.page,
    snapshot: snapshot,
    profile: profile,
    session_embed_summary: { topics: ["test"], centroid_bucket: "test-bkt-01" },
    constraints: { p95_budget_ms: 1000, max_sections: 6 }
  )
  puts "   ✅ Plan received from Operator"
end

puts "   Plan ID: #{plan[:plan_id]}"
puts "   Source: #{plan[:source]}"
puts "   TTL: #{plan[:ttl_seconds]} seconds"
puts "   Sections: #{plan[:sections].count}"
puts ""

puts "📋 Section Details:"
plan[:sections].each_with_index do |section, index|
  puts "   #{index + 1}. #{section[:id]} (#{section[:count]} items)"
  puts "      Reason: #{section[:reason]}"
  puts "      Filters: #{section[:filters].inspect}"
end
puts ""

# Execute plan sections
puts "⚙️  Step 6: Executing Plan Sections..."
session_embed_summary = { topics: ["test"], centroid_bucket: "test-bkt-01" }

sections = DemoPersonalizedFeeds.execute_plan_sections(
  plan, 
  snapshot, 
  profile, 
  session_embed_summary
)

puts "   ✅ Plan execution completed"
puts ""

puts "📊 Section Results:"
total_products = 0
sections.each_with_index do |section, index|
  product_count = section[:products].count
  total_products += product_count
  puts "   #{index + 1}. #{section[:id]}: #{product_count} products"
  puts "      Pre-guard candidates: #{section[:pre_guard_candidates]&.count || 0}"
  puts "      After guardrails: #{section[:products].count}"
end
puts ""

puts "📈 Final Results:"
puts "   Total Sections: #{sections.count}"
puts "   Total Products: #{total_products}"
puts "   Plan Source: #{plan[:source]}"
puts ""

if total_products > 0
  puts "🎉 SUCCESS! End-to-end personalization flow is working!"
  puts "   Rails can generate plans and retrieve products successfully"
  puts "   The system is ready for frontend integration"
else
  puts "❌ ISSUE: No products were returned"
  puts "   This indicates a problem with the retrieval or guardrails logic"
end

puts ""
puts "🔍 End-to-End Test Complete!"
puts "=" * 50
