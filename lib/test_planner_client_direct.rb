#!/usr/bin/env ruby

puts "🔍 Testing PlannerClient Direct Communication"
puts "=" * 50

# Set up environment
ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
ENV['OPERATOR_TIMEOUT_MS'] = '700'

puts "⚙️  Environment configured:"
puts "   Operator URL: #{ENV['PERSONALIZATION_OPERATOR_URL']}"
puts "   Timeout: #{ENV['OPERATOR_TIMEOUT_MS']}ms"
puts ""

# Test data
snapshot = {
  region: "ke",
  pickup_only: false,
  last_search: "",
  views_10m: 0,
  recent_add_to_cart: false,
  inactivity_bucket: "dormant",
  pid: nil
}

profile = {
  price_band: "low",
  top_categories: [],
  brand_top: [],
  shop_top: [],
  freshness_pref: 0.5,
  diversity_pref: 0.5
}

session_embed_summary = {
  topics: ["test"],
  centroid_bucket: "test-bkt-01"
}

constraints = {
  p95_budget_ms: 1000,
  max_sections: 6
}

puts "📡 Testing PlannerClient.fetch_plan..."
puts "   Page: home"
puts "   Region: #{snapshot[:region]}"
puts "   Price Band: #{profile[:price_band]}"
puts ""

begin
  plan = Personalization::PlannerClient.fetch_plan(
    page: "home",
    snapshot: snapshot,
    profile: profile,
    session_embed_summary: session_embed_summary,
    constraints: constraints
  )
  
  puts "✅ SUCCESS! Plan received:"
  puts "   Plan type: #{plan.class}"
  puts "   Plan keys: #{plan.keys if plan.respond_to?(:keys)}"
  puts "   Plan ID: #{plan['plan_id'] || plan[:plan_id]}"
  puts "   Source: #{plan['source'] || plan[:source]}"
  puts "   TTL: #{plan['ttl_seconds'] || plan[:ttl_seconds]} seconds"
  puts "   Sections: #{plan['sections']&.length || plan[:sections]&.length || 0}"
  puts ""
  
  puts "📋 Section Details:"
  if plan['sections']&.is_a?(Array)
    plan['sections'].each_with_index do |section, index|
      puts "   #{index + 1}. #{section['id']} (#{section['count']} items)"
      puts "      Reason: #{section['reason']}"
    end
  else
    puts "   No sections data available"
  end
  puts ""
  
  if plan['source'] == 'llm'
    puts "🎉 LLM PLAN SUCCESS!"
    puts "   Rails is successfully communicating with the Python Operator"
    puts "   AI-powered personalization is working!"
  else
    puts "⚠️  CONTROL PLAN FALLBACK"
    puts "   Rails fell back to control plan instead of LLM plan"
    puts "   This indicates an issue with the Operator communication"
  end
  
rescue => e
  puts "❌ ERROR: #{e.class}: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  puts "   This indicates a problem with the PlannerClient"
end

puts ""
puts "🔍 PlannerClient Test Complete!"
puts "=" * 50
