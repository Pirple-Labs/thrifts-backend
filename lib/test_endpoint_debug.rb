#!/usr/bin/env ruby

puts "🔍 Debugging PlannerClient Endpoint"
puts "=" * 40

# Set up environment
ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
ENV['OPERATOR_TIMEOUT_MS'] = '10000'

puts "📡 Environment Variables:"
puts "   PERSONALIZATION_OPERATOR_URL: #{ENV['PERSONALIZATION_OPERATOR_URL']}"
puts "   OPERATOR_TIMEOUT_MS: #{ENV['OPERATOR_TIMEOUT_MS']}"
puts ""

# Check what endpoint the PlannerClient is using
endpoint = Personalization::PlannerClient::ENDPOINT
timeout = Personalization::PlannerClient::TIMEOUT_MS

puts "📋 PlannerClient Configuration:"
puts "   ENDPOINT: #{endpoint}"
puts "   TIMEOUT_MS: #{timeout}"
puts ""

# Test the endpoint directly
puts "🧪 Testing endpoint directly..."
require 'http'

begin
  # Test with a simple request
  response = HTTP.timeout(5.0).get(endpoint.gsub('/operator/query-pack', '/health'))
  puts "   Health check: #{response.status} - #{response.body}"
rescue => e
  puts "   Health check failed: #{e.message}"
end

puts ""
puts "🔍 Debug Complete!"

