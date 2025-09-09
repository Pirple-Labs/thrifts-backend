# frozen_string_literal: true

namespace :operator do
  desc "Start mock Operator service for testing"
  task :start_mock => :environment do
    puts "🚀 Starting Mock Operator Service..."
    puts "📡 This will start a mock Flask Operator service on port 8000"
    puts "🔗 Rails will connect to: http://localhost:8000"
    puts ""
    
    # Set environment variables for Rails to connect to mock service
    ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
    ENV['OPERATOR_TIMEOUT_MS'] = '700'
    ENV['PERSONALIZATION_JWT_SECRET'] = Rails.application.secret_key_base
    ENV['ENABLE_OPERATOR'] = 'true'
    
    puts "⚙️  Environment configured:"
    puts "   PERSONALIZATION_OPERATOR_URL=http://localhost:8000"
    puts "   OPERATOR_TIMEOUT_MS=700"
    puts "   ENABLE_OPERATOR=true"
    puts ""
    
    # Start the mock service
    MockOperatorService.start_server(port: 8000)
  end
  
  desc "Test Operator connection"
  task :test_connection => :environment do
    puts "🧪 Testing Operator connection..."
    
    # Set environment variables
    ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
    ENV['OPERATOR_TIMEOUT_MS'] = '700'
    ENV['PERSONALIZATION_JWT_SECRET'] = Rails.application.secret_key_base
    ENV['ENABLE_OPERATOR'] = 'true'
    
    # Test data
    snapshot = {
      page: "home",
      region: "ke",
      pickup_only: false,
      user_id: 1,
      session_id: "test_session",
      views_10m: [],
      recent_add_to_cart: false,
      inactivity_bucket: "active",
      pid: nil
    }
    
    profile = {
      price_band: "mid",
      top_categories: ["Electronics", "Fashion"],
      brand_top: ["Apple", "Nike"],
      shop_top: ["TechStore", "FashionHub"],
      freshness_pref: 0.6,
      diversity_pref: 0.7
    }
    
    session_embed_summary = {
      topics: ["electronics", "fashion"],
      centroid_bucket: "v3-bkt-12"
    }
    
    constraints = {
      p95_budget_ms: 1000,
      max_sections: 6
    }
    
    begin
      puts "📡 Sending request to Operator..."
      plan = Personalization::PlannerClient.fetch_plan(
        page: "home",
        snapshot: snapshot,
        profile: profile,
        session_embed_summary: session_embed_summary,
        constraints: constraints
      )
      
      puts "✅ Connection successful!"
      puts "📋 Plan received:"
      puts "   Plan ID: #{plan[:plan_id]}"
      puts "   Source: #{plan[:source]}"
      puts "   Page: #{plan[:page]}"
      puts "   Sections: #{plan[:sections]&.count || 0}"
      puts "   TTL: #{plan[:ttl_seconds]} seconds"
      
      if plan[:sections]
        puts "   Section details:"
        plan[:sections].each_with_index do |section, index|
          puts "     #{index + 1}. #{section[:id]} (#{section[:count]} items)"
          puts "        Reason: #{section[:reason]}"
        end
      end
      
    rescue => e
      puts "❌ Connection failed: #{e.message}"
      puts "💡 Make sure the mock Operator service is running:"
      puts "   rails operator:start_mock"
    end
  end
  
  desc "Show Operator endpoints"
  task :endpoints => :environment do
    puts "📡 Operator Service Endpoints:"
    puts ""
    puts "🔗 Base URL: http://localhost:8000"
    puts ""
    puts "📋 Available Endpoints:"
    puts "   POST /operator/query-pack    - Generate personalized plans"
    puts "   GET  /health                 - Health check"
    puts "   GET  /operator/metrics       - Prometheus metrics"
    puts "   GET  /operator/version       - Version information"
    puts ""
    puts "🧪 Test Commands:"
    puts "   curl http://localhost:8000/health"
    puts "   curl http://localhost:8000/operator/version"
    puts "   curl http://localhost:8000/operator/metrics"
    puts ""
    puts "🎮 Demo Endpoints:"
    puts "   GET  /api/demo/personalized-feed?page=home&user_id=1"
    puts "   GET  /api/demo/personalized-feed?page=search&user_id=1"
    puts "   GET  /api/demo/personalized-feed?page=pdp&user_id=1"
    puts "   GET  /api/demo/personalized-feed?page=profile&user_id=1"
  end
  
  desc "Run personalized feeds demo"
  task :demo => :environment do
    puts "🎯 Starting Personalized Feeds Demo..."
    puts ""
    
    # Set environment variables
    ENV['PERSONALIZATION_OPERATOR_URL'] = 'http://localhost:8000'
    ENV['OPERATOR_TIMEOUT_MS'] = '700'
    ENV['PERSONALIZATION_JWT_SECRET'] = Rails.application.secret_key_base
    ENV['ENABLE_OPERATOR'] = 'true'
    
    # Run the demo
    DemoPersonalizedFeeds.run
  end
end
