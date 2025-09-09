#!/usr/bin/env ruby

# Debug script to test Operator request directly
puts "🔍 Debugging Operator Request"
puts "=" * 40

# Set up environment
ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
ENV['OPERATOR_TIMEOUT_MS'] = '700'
ENV['PERSONALIZATION_JWT_SECRET'] = Rails.application.secret_key_base
ENV['ENABLE_OPERATOR'] = 'true'

# Build payload
payload = {
  page: "home",
  snapshot: {
    region: "ke",
    pickup_only: false,
    last_search: nil,
    views_10m: [],
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
    profile_hash: "00___1000_1000_00",
    ttl_seconds: 172800
  }
}

# Build headers
jwt_token = Personalization::PlannerClient.send(:generate_jwt_token)
headers = {
  "Content-Type" => "application/json",
  "Accept" => "application/json",
  "Authorization" => "Bearer #{jwt_token}",
  "X-Request-Id" => SecureRandom.uuid,
  "X-Plan-DSL-Version" => "1.0-mvp"
}

puts "📡 Making HTTP Request..."
puts "   URL: #{ENV['PERSONALIZATION_OPERATOR_URL']}/operator/query-pack"
puts "   JWT Token: #{jwt_token[0..20]}..."
puts "   Payload size: #{payload.to_json.length} bytes"
puts ""

begin
  http = HTTP.timeout(5.0).headers(headers)
  resp = http.post("#{ENV['PERSONALIZATION_OPERATOR_URL']}/operator/query-pack", json: payload)
  
  puts "📊 Response Details:"
  puts "   Status: #{resp.status}"
  puts "   Headers: #{resp.headers.to_h}"
  puts "   Body length: #{resp.body.length} bytes"
  puts ""
  
  if resp.status.success?
    json_response = resp.parse
    puts "✅ Success! Response:"
    puts "   Plan ID: #{json_response['plan_id']}"
    puts "   Source: #{json_response['source']}"
    puts "   TTL: #{json_response['ttl_seconds']}"
    puts "   Sections: #{json_response['sections']&.count || 0}"
    puts ""
    
    if json_response['sections']
      puts "📋 Sections:"
      json_response['sections'].each_with_index do |section, index|
        puts "   #{index + 1}. #{section['id']} (#{section['count']} items)"
        puts "      Reason: #{section['reason']}"
      end
    end
  else
    puts "❌ Error Response:"
    puts "   Status: #{resp.status}"
    puts "   Body: #{resp.body}"
  end
  
rescue => e
  puts "❌ Exception: #{e.class}: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
end

puts ""
puts "🔍 Debug Complete!"

