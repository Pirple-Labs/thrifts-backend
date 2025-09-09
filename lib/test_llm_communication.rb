#!/usr/bin/env ruby

puts "🧠 Testing LLM Communication"
puts "=" * 50

# Set up environment
ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
ENV['OPERATOR_TIMEOUT_MS'] = '30000'

# Build snapshot
snapshot = {
  user_id: 1,
  page: 'home',
  session_id: 'test_session',
  region: 'ke',
  pickup_only: false,
  recent_views: [],
  recent_cart_activity: false,
  activity_level: 'dormant'
}

# Build profile
profile = {
  price_band: 'low',
  top_categories: [],
  brand_preferences: [],
  shop_preferences: [],
  freshness_preference: 0.5,
  diversity_preference: 0.5
}

# Build session embedding summary
session_embed_summary = {
  topics: ['test', 'llm'],
  centroid_bucket: 'test-bkt-01'
}

# Constraints
constraints = {
  p95_budget_ms: 1000,
  max_sections: 6
}

puts "📡 Sending request to LLM..."
puts "URL: #{ENV['PERSONALIZATION_OPERATOR_URL']}"
puts "Timeout: #{ENV['OPERATOR_TIMEOUT_MS']}ms"
puts ""

begin
  # Test LLM communication
  plan = Personalization::PlannerClient.fetch_plan(
    page: 'home',
    snapshot: snapshot,
    profile: profile,
    session_embed_summary: session_embed_summary,
    constraints: constraints
  )
  
  puts "✅ LLM Response Received!"
  puts "Plan Source: #{plan[:source] || plan['source']}"
  puts "Plan ID: #{plan[:plan_id] || plan['plan_id']}"
  puts "Sections: #{plan[:sections]&.length || plan['sections']&.length || 0}"
  puts ""
  
  if plan[:sections] || plan['sections']
    sections = plan[:sections] || plan['sections']
    puts "📋 Section Details:"
    sections.each_with_index do |section, i|
      section = section.deep_symbolize_keys if section.is_a?(Hash)
      puts "  #{i + 1}. #{section[:id] || section['id']}"
      puts "     Title: #{section[:title] || section['title']}"
      puts "     Reason: #{section[:reason] || section['reason']}"
      puts "     Count: #{section[:count] || section['count']}"
      puts ""
    end
  end
  
rescue => e
  puts "❌ LLM Communication Failed!"
  puts "Error: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
end

puts "🔍 Test Complete"
