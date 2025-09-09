#!/usr/bin/env ruby

puts "🔍 Testing PlannerClient with Logging"
puts "=" * 40

# Set up environment
ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
ENV['OPERATOR_TIMEOUT_MS'] = '30000'

puts "📡 Testing PlannerClient.fetch_plan..."
puts "   Operator URL: #{ENV['PERSONALIZATION_OPERATOR_URL']}"
puts "   Timeout: #{ENV['OPERATOR_TIMEOUT_MS']}ms"
puts ""

# Enable Rails logging
Rails.logger.level = :debug

begin
  result = Personalization::PlannerClient.fetch_plan(
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
    session_embed_summary: { 
      topics: ["test"], 
      centroid_bucket: "test-bkt-01" 
    },
    constraints: { 
      p95_budget_ms: 1000, 
      max_sections: 6 
    }
  )
  
  puts "✅ Result received:"
  puts "   Result: #{result.inspect}"
  puts "   Source: #{result&.dig(:source) || 'nil'}"
  puts "   Plan ID: #{result&.dig(:plan_id) || 'nil'}"
  puts "   Sections: #{result&.dig(:sections)&.length || 'nil'}"
  puts ""
  
  if result.nil?
    puts "❌ NULL RESULT"
    puts "   The PlannerClient returned nil instead of a plan"
    puts "   This indicates an error in the PlannerClient code"
  elsif result[:source] == 'control'
    puts "⚠️  CONTROL PLAN FALLBACK"
    puts "   The PlannerClient fell back to control plan"
    puts "   This means there was an error communicating with the Python Operator"
    puts "   Check the Rails logs above for error details"
  else
    puts "🎉 LLM PLAN SUCCESS!"
    puts "   Rails successfully received an LLM-generated plan from the Python Operator"
  end
  
rescue => e
  puts "❌ Exception: #{e.class}: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
end

puts ""
puts "🔍 Test Complete!"
