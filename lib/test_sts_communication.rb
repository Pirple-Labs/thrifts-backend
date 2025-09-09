#!/usr/bin/env ruby

require 'json'
require 'http'

puts "🔗 Testing STS Communication (No JWT)"
puts "=" * 50

# Set up environment
ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
ENV['OPERATOR_TIMEOUT_MS'] = '700'
ENV['ENABLE_OPERATOR'] = 'true'

puts "⚙️  Environment configured:"
puts "   Rails Backend: http://localhost:3000"
puts "   Python Operator: http://localhost:8000"
puts "   Authentication: STS (No JWT)"
puts ""

# Test payload
payload = {
  page: "home",
  snapshot: {
    region: "ke",
    pickup_only: false,
    last_search: "",
    views_10m: 0,
    recent_add_to_cart: false,
    inactivity_bucket: "dormant",
    pid: nil
  },
  profile: {
    price_band: "low",
    top_categories: [],
    brand_top: [],
    shop_top: [],
    freshness_pref: 0.5,
    diversity_pref: 0.5
  },
  constraints: {
    p95_budget_ms: 1000,
    max_sections: 6
  },
  session_embed_summary: {
    topics: ["test"],
    centroid_bucket: "test-bkt-01"
  },
  plan_cache_hint: {
    profile_hash: "test_hash",
    ttl_seconds: 172800
  }
}

puts "📡 Sending STS Request to Python Operator..."
puts "   Endpoint: #{ENV['PERSONALIZATION_OPERATOR_URL']}/operator/query-pack"
puts "   Payload size: #{JSON.generate(payload).length} bytes"
puts ""

# Make HTTP request without JWT

begin
  http = HTTP.timeout(10.0)
  
  headers = {
    "Content-Type" => "application/json",
    "Accept" => "application/json",
    # No Authorization header for STS communication
    "X-Request-Id" => SecureRandom.uuid,
    "X-Plan-DSL-Version" => "1.0-mvp"
  }
  
  puts "📤 Request Headers:"
  headers.each { |k, v| puts "   #{k}: #{v}" }
  puts ""
  
  resp = http.headers(headers).post("#{ENV['PERSONALIZATION_OPERATOR_URL']}/operator/query-pack", json: payload)
  
  puts "📊 Operator Response:"
  puts "   Status: #{resp.status}"
  puts "   Headers: #{resp.headers.to_h}"
  puts ""
  
  if resp.status.success?
    json_response = resp.parse
    puts "✅ SUCCESS! STS Communication Working!"
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
      end
    end
    
    puts ""
    puts "🎉 STS COMMUNICATION SUCCESSFUL!"
    puts "   Rails can now communicate with Python Operator without JWT!"
    
  else
    puts "❌ ERROR Response:"
    puts "   Status: #{resp.status}"
    puts "   Body: #{resp.body}"
    puts ""
    puts "🔍 This means the Python Operator still requires JWT authentication"
    puts "   The AI team needs to update the Python Operator to skip JWT validation"
  end
  
rescue => e
  puts "❌ Exception: #{e.class}: #{e.message}"
  puts "   This means Rails couldn't connect to the Python Operator"
end

puts ""
puts "🔍 STS Communication Test Complete!"
puts "=" * 50
