#!/usr/bin/env ruby

puts "🔗 Testing Real Rails-Operator Communication"
puts "=" * 50

# Set up environment
ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
ENV['OPERATOR_TIMEOUT_MS'] = '700'
ENV['PERSONALIZATION_JWT_SECRET'] = Rails.application.secret_key_base
ENV['ENABLE_OPERATOR'] = 'true'

puts "⚙️  Environment configured:"
puts "   Rails Backend: http://localhost:3000"
puts "   Python Operator: http://localhost:8000"
puts "   JWT Secret: #{ENV['PERSONALIZATION_JWT_SECRET'][0..10]}..."
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
puts ""

# Build profile
puts "👤 Step 2: Building Profile..."
profile = Personalization::ProfileStore.slice(request.user_id)
puts "   ✅ Profile built successfully"
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

# Generate JWT token
puts "🔐 Step 4: Generating JWT Token..."
jwt_token = Personalization::PlannerClient.send(:generate_jwt_token)
puts "   JWT Token: #{jwt_token[0..30]}..."
puts ""

# Build payload
payload = {
  page: request.page,
  snapshot: {
    region: snapshot[:region],
    pickup_only: snapshot[:pickup_only],
    last_search: snapshot[:last_search],
    views_10m: snapshot[:views_10m]&.count || 0,
    recent_add_to_cart: snapshot[:recent_add_to_cart],
    inactivity_bucket: snapshot[:inactivity_bucket],
    pid: snapshot[:pid]
  },
  profile: profile,
  constraints: {
    p95_budget_ms: 1000,
    max_sections: 6
  },
  session_embed_summary: session_embed_summary,
  plan_cache_hint: {
    profile_hash: profile_hash,
    ttl_seconds: 172800
  }
}

puts "📡 Step 5: Sending Request to Python Operator..."
puts "   Endpoint: #{ENV['PERSONALIZATION_OPERATOR_URL']}/operator/query-pack"
puts "   Payload size: #{payload.to_json.length} bytes"
puts ""

# Make HTTP request using Rails' HTTP gem
require 'http'

begin
  http = HTTP.timeout(5.0)
  
  headers = {
    "Content-Type" => "application/json",
    "Accept" => "application/json",
    "Authorization" => "Bearer #{jwt_token}",
    "X-Request-Id" => SecureRandom.uuid,
    "X-Plan-DSL-Version" => "1.0-mvp"
  }
  
  puts "📤 Request Headers:"
  headers.each { |k, v| puts "   #{k}: #{v[0..30]}#{v.length > 30 ? '...' : ''}" }
  puts ""
  
  resp = http.headers(headers).post("#{ENV['PERSONALIZATION_OPERATOR_URL']}/operator/query-pack", json: payload)
  
  puts "📊 Step 6: Operator Response:"
  puts "   Status: #{resp.status}"
  puts "   Headers: #{resp.headers.to_h}"
  puts ""
  
  if resp.status.success?
    json_response = resp.parse
    puts "✅ SUCCESS! Python Operator Response:"
    puts "   Plan ID: #{json_response['plan_id']}"
    puts "   Source: #{json_response['source']}"
    puts "   TTL: #{json_response['ttl_seconds']} seconds"
    puts "   Sections: #{json_response['sections']&.count || 0}"
    puts ""
    
    if json_response['sections']
      puts "📋 Section Details:"
      json_response['sections'].each_with_index do |section, index|
        puts "   #{index + 1}. #{section['id']} (#{section['count']} items)"
        puts "      Reason: #{section['reason']}"
        puts "      Filters: #{section['filters']}"
      end
    end
    
    puts ""
    puts "🎉 RAILS-OPERATOR COMMUNICATION SUCCESSFUL!"
    puts "   The Python Flask Operator is responding with LLM-generated plans!"
    
  else
    puts "❌ ERROR Response:"
    puts "   Status: #{resp.status}"
    puts "   Body: #{resp.body}"
    puts ""
    puts "🔍 This means the Python Operator rejected our request"
    puts "   Possible issues: JWT validation, request format, or Operator logic"
  end
  
rescue => e
  puts "❌ Exception: #{e.class}: #{e.message}"
  puts "   This means Rails couldn't connect to the Python Operator"
end

puts ""
puts "🔍 Communication Test Complete!"
puts "=" * 50

