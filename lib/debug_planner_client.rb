#!/usr/bin/env ruby

puts "🔍 Debugging PlannerClient Response"
puts "=" * 40

# Set up environment
ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
ENV['OPERATOR_TIMEOUT_MS'] = '700'

puts "Testing PlannerClient.fetch_plan..."

begin
  # Test with minimal data
  result = Personalization::PlannerClient.fetch_plan(
    page: "home",
    snapshot: { region: "ke", pickup_only: false, last_search: "", views_10m: 0, recent_add_to_cart: false, inactivity_bucket: "dormant", pid: nil },
    profile: { price_band: "low", top_categories: [], brand_top: [], shop_top: [], freshness_pref: 0.5, diversity_pref: 0.5 },
    session_embed_summary: { topics: ["test"], centroid_bucket: "test-bkt-01" },
    constraints: { p95_budget_ms: 1000, max_sections: 6 }
  )
  
  puts "✅ Result received:"
  puts "   Type: #{result.class}"
  puts "   Value: #{result.inspect}"
  
  if result.is_a?(Hash)
    puts "   Keys: #{result.keys}"
    puts "   Source: #{result[:source] || result['source']}"
  elsif result.is_a?(Integer)
    puts "   ⚠️  Got integer instead of hash - this is the problem!"
  end
  
rescue => e
  puts "❌ Exception: #{e.class}: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(2).join("\n   ")}"
end

puts ""
puts "🔍 Debug Complete!"

