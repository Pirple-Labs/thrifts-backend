#!/usr/bin/env ruby

puts "🔍 Simple Operator Test"
puts "=" * 30

# Test direct HTTP request to Operator
require 'net/http'
require 'json'
require 'uri'

uri = URI('http://localhost:8000/operator/query-pack')
http = Net::HTTP.new(uri.host, uri.port)

request = Net::HTTP::Post.new(uri)
request['Content-Type'] = 'application/json'
request['Authorization'] = 'Bearer test-token-123'
request['X-Request-Id'] = SecureRandom.uuid
request['X-Plan-DSL-Version'] = '1.0-mvp'

payload = {
  page: "home",
  snapshot: {
    region: "ke",
    pickup_only: false
  },
  profile: {
    price_band: "low"
  },
  constraints: {
    p95_budget_ms: 1000,
    max_sections: 6
  }
}

request.body = payload.to_json

puts "📡 Sending request to: #{uri}"
puts "📊 Payload: #{payload.to_json}"
puts ""

begin
  response = http.request(request)
  
  puts "📊 Response:"
  puts "   Status: #{response.code}"
  puts "   Headers: #{response.to_hash}"
  puts "   Body: #{response.body}"
  
  if response.code == '200'
    json_response = JSON.parse(response.body)
    puts ""
    puts "✅ Success!"
    puts "   Plan ID: #{json_response['plan_id']}"
    puts "   Source: #{json_response['source']}"
    puts "   TTL: #{json_response['ttl_seconds']}"
    puts "   Sections: #{json_response['sections']&.count || 0}"
  else
    puts ""
    puts "❌ Error: #{response.code}"
  end
  
rescue => e
  puts "❌ Exception: #{e.class}: #{e.message}"
end

puts ""
puts "🔍 Test Complete!"

