#!/usr/bin/env ruby

puts "🔄 Testing LLM End-to-End Personalization Flow"
puts "=" * 50

# Set up environment to use Operator (test LLM plans)
ENV['ENABLE_OPERATOR'] = 'true'
ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
ENV['OPERATOR_TIMEOUT_MS'] = '30000'

puts "⚙️  Environment configured:"
puts "   Operator: ENABLED (using LLM plans)"
puts "   Rails Backend: http://localhost:3000"
puts "   Timeout: 30 seconds"
puts ""

# Create mock request and session objects with different user ID to avoid cache
request = OpenStruct.new(
  user_id: 999, # Different user ID to avoid cache
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
puts "   User ID: #{request.user_id} (new user to avoid cache)"
puts "   Session ID: #{request.session_id}"
puts "   Region: #{request.region}"
puts ""

# Build snapshot
puts "🔍 Step 1: Building Snapshot..."
snapshot = Personalization::SnapshotBuilder.build(request, session)
puts "   ✅ Snapshot built successfully"
puts ""

# Build profile
puts "👤 Step 2: Building Profile..."
profile = Personalization::ProfileStore.slice(request.user_id)
puts "   ✅ Profile built successfully"
puts ""

# Get profile hash
profile_hash = Personalization::ProfileHasher.hash(snapshot, profile)
puts "🔑 Step 3: Profile Hash: #{profile_hash}"
puts ""

# Get plan (should fetch from Operator since it's a new user)
puts "📋 Step 4: Getting Plan from Operator..."
plan = Personalization::PlannerClient.fetch_plan(
  page: request.page,
  snapshot: snapshot,
  profile: profile,
  session_embed_summary: { topics: ["test"], centroid_bucket: "test-bkt-01" },
  constraints: { p95_budget_ms: 1000, max_sections: 6 }
)

puts "   ✅ Plan received from Operator"
puts "   Plan ID: #{plan['plan_id']}"
puts "   Source: #{plan['source']}"
puts "   TTL: #{plan['ttl_seconds']} seconds"
puts "   Sections: #{plan['sections'].length}"
puts ""

puts "📋 Section Details:"
plan['sections'].each_with_index do |section, index|
  puts "   #{index + 1}. #{section['id']} (#{section['count']} items)"
  puts "      Reason: #{section['reason']}"
end
puts ""

# Execute plan sections
puts "⚙️  Step 5: Executing Plan Sections..."
sections = DemoPersonalizedFeeds.execute_plan_sections(
  plan, 
  snapshot, 
  profile, 
  { topics: ["test"], centroid_bucket: "test-bkt-01" }
)

puts "   ✅ Plan execution completed"
puts ""

puts "📊 Section Results:"
total_products = 0
sections.each_with_index do |section, index|
  product_count = section[:products].count
  total_products += product_count
  puts "   #{index + 1}. #{section[:id]}: #{product_count} products"
end
puts ""

puts "📈 Final Results:"
puts "   Total Sections: #{sections.count}"
puts "   Total Products: #{total_products}"
puts "   Plan Source: #{plan['source']}"
puts ""

if plan['source'] == 'llm'
  puts "🎉 LLM PERSONALIZATION SUCCESS!"
  puts "   Rails successfully received and executed an AI-generated plan"
  puts "   The intelligent shopping assistant is working with LLM-powered recommendations!"
else
  puts "⚠️  CONTROL PLAN FALLBACK"
  puts "   Rails fell back to control plan instead of LLM plan"
end

puts ""
puts "🔍 LLM End-to-End Test Complete!"
puts "=" * 50

