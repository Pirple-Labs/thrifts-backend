# frozen_string_literal: true

# Mock Operator Service for testing and demonstration
class MockOperatorService
  def self.start_server(port: 8000)
    require 'webrick'
    require 'json'
    
    server = WEBrick::HTTPServer.new(Port: port)
    
    server.mount_proc '/operator/query-pack' do |req, res|
      handle_query_pack(req, res)
    end
    
    server.mount_proc '/health' do |req, res|
      res.status = 200
      res['Content-Type'] = 'application/json'
      res.body = { status: 'healthy', timestamp: Time.current }.to_json
    end
    
    server.mount_proc '/operator/metrics' do |req, res|
      res.status = 200
      res['Content-Type'] = 'text/plain'
      res.body = generate_prometheus_metrics
    end
    
    server.mount_proc '/operator/version' do |req, res|
      res.status = 200
      res['Content-Type'] = 'application/json'
      res.body = {
        version: '1.0.0',
        schema_version: '1.0-mvp',
        build_time: Time.current.iso8601
      }.to_json
    end
    
    puts "🚀 Mock Operator Service starting on port #{port}"
    puts "📡 Endpoints:"
    puts "   POST /operator/query-pack"
    puts "   GET  /health"
    puts "   GET  /operator/metrics"
    puts "   GET  /operator/version"
    puts "🛑 Press Ctrl+C to stop"
    
    trap 'INT' do
      server.shutdown
    end
    
    server.start
  end
  
  private
  
  def self.handle_query_pack(req, res)
    # Parse request
    request_data = JSON.parse(req.body)
    page = request_data['page']
    
    # For STS (Same Trust Store) communications, skip JWT validation
    # Internal services can communicate without authentication
    puts "🔐 STS Communication: Skipping JWT validation for internal service"
    puts "📊 Request data: page=#{page}, region=#{request_data.dig('snapshot', 'region')}"
    puts "✅ Internal service authentication passed"
    
    # Simulate processing time
    sleep(rand(0.1..0.5))
    
    # Generate mock plan
    plan = generate_mock_plan(page, request_data)
    
    res.status = 200
    res['Content-Type'] = 'application/json'
    res.body = plan.to_json
  end
  
  def self.generate_mock_plan(page, request_data)
    # Mock plan generation based on page type
    case page
    when 'home'
      {
        plan_id: "plan_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}_home_v1",
        source: "llm",
        ttl_seconds: 172800,
        page: "home",
        sections: [
          {
            id: "session_picks",
            count: 12,
            filters: {
              categories: request_data.dig('profile', 'top_categories') || [],
              price_band: request_data.dig('profile', 'price_band') || 'mid',
              fresh_days: 0,
              region: request_data.dig('snapshot', 'region') || 'ke',
              pickup_only: request_data.dig('snapshot', 'pickup_only') || false
            },
            reason: "Based on your recent activity and preferences"
          },
          {
            id: "lookalikes",
            count: 12,
            filters: {
              categories: request_data.dig('profile', 'top_categories') || [],
              price_band: request_data.dig('profile', 'price_band') || 'mid',
              fresh_days: 30,
              region: request_data.dig('snapshot', 'region') || 'ke',
              pickup_only: request_data.dig('snapshot', 'pickup_only') || false
            },
            reason: "Similar to what you've been browsing"
          },
          {
            id: "trending_near_you",
            count: 12,
            filters: {
              categories: [],
              price_band: request_data.dig('profile', 'price_band') || 'mid',
              fresh_days: 7,
              region: request_data.dig('snapshot', 'region') || 'ke',
              pickup_only: request_data.dig('snapshot', 'pickup_only') || false
            },
            reason: "Trending in your area"
          }
        ],
        copy_style: { tone: "friendly", max_reason_len: 80 },
        version: "1.0-mvp"
      }
    when 'search'
      {
        plan_id: "plan_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}_search_v1",
        source: "llm",
        ttl_seconds: 172800,
        page: "search",
        sections: [
          {
            id: "search_results",
            count: 24,
            filters: {
              categories: [],
              price_band: request_data.dig('profile', 'price_band') || 'mid',
              fresh_days: 0,
              region: request_data.dig('snapshot', 'region') || 'ke',
              pickup_only: request_data.dig('snapshot', 'pickup_only') || false
            },
            reason: "Search results for your query"
          },
          {
            id: "lookalikes",
            count: 12,
            filters: {
              categories: [],
              price_band: request_data.dig('profile', 'price_band') || 'mid',
              fresh_days: 30,
              region: request_data.dig('snapshot', 'region') || 'ke',
              pickup_only: request_data.dig('snapshot', 'pickup_only') || false
            },
            reason: "Similar items you might like"
          }
        ],
        copy_style: { tone: "friendly", max_reason_len: 80 },
        version: "1.0-mvp"
      }
    when 'pdp'
      {
        plan_id: "plan_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}_pdp_v1",
        source: "llm",
        ttl_seconds: 172800,
        page: "pdp",
        sections: [
          {
            id: "similar_items",
            count: 12,
            filters: {
              categories: [],
              price_band: request_data.dig('profile', 'price_band') || 'mid',
              fresh_days: 0,
              region: request_data.dig('snapshot', 'region') || 'ke',
              pickup_only: request_data.dig('snapshot', 'pickup_only') || false
            },
            reason: "Similar products you might like"
          },
          {
            id: "complete_the_look",
            count: 6,
            filters: {
              categories: [],
              price_band: request_data.dig('profile', 'price_band') || 'mid',
              fresh_days: 0,
              region: request_data.dig('snapshot', 'region') || 'ke',
              pickup_only: request_data.dig('snapshot', 'pickup_only') || false
            },
            reason: "Complete the look"
          },
          {
            id: "more_from_shop",
            count: 8,
            filters: {
              categories: [],
              price_band: request_data.dig('profile', 'price_band') || 'mid',
              fresh_days: 0,
              region: request_data.dig('snapshot', 'region') || 'ke',
              pickup_only: request_data.dig('snapshot', 'pickup_only') || false
            },
            reason: "More from this shop"
          }
        ],
        copy_style: { tone: "friendly", max_reason_len: 80 },
        version: "1.0-mvp"
      }
    when 'profile'
      {
        plan_id: "plan_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}_profile_v1",
        source: "llm",
        ttl_seconds: 172800,
        page: "profile",
        sections: [
          {
            id: "top_picks_for_you",
            count: 12,
            filters: {
              categories: request_data.dig('profile', 'top_categories') || [],
              price_band: request_data.dig('profile', 'price_band') || 'mid',
              fresh_days: 0,
              region: request_data.dig('snapshot', 'region') || 'ke',
              pickup_only: request_data.dig('snapshot', 'pickup_only') || false
            },
            reason: "Top picks for you"
          },
          {
            id: "new_in_favorites",
            count: 12,
            filters: {
              categories: [],
              price_band: request_data.dig('profile', 'price_band') || 'mid',
              fresh_days: 7,
              region: request_data.dig('snapshot', 'region') || 'ke',
              pickup_only: request_data.dig('snapshot', 'pickup_only') || false
            },
            reason: "New in your favorites"
          },
          {
            id: "from_shops_you_like",
            count: 12,
            filters: {
              categories: [],
              price_band: request_data.dig('profile', 'price_band') || 'mid',
              fresh_days: 0,
              region: request_data.dig('snapshot', 'region') || 'ke',
              pickup_only: request_data.dig('snapshot', 'pickup_only') || false
            },
            reason: "From shops you like"
          }
        ],
        copy_style: { tone: "friendly", max_reason_len: 80 },
        version: "1.0-mvp"
      }
    else
      # Default to home page
      generate_mock_plan('home', request_data)
    end
  end
  
  def self.generate_prometheus_metrics
    <<~METRICS
      # HELP operator_requests_total Total number of requests to the operator
      # TYPE operator_requests_total counter
      operator_requests_total{endpoint="query-pack"} #{rand(1000..5000)}
      
      # HELP operator_response_time_seconds Response time in seconds
      # TYPE operator_response_time_seconds histogram
      operator_response_time_seconds_bucket{le="0.1"} #{rand(100..500)}
      operator_response_time_seconds_bucket{le="0.5"} #{rand(500..800)}
      operator_response_time_seconds_bucket{le="1.0"} #{rand(800..950)}
      operator_response_time_seconds_bucket{le="+Inf"} #{rand(950..1000)}
      operator_response_time_seconds_count #{rand(950..1000)}
      operator_response_time_seconds_sum #{rand(200..400)}
      
      # HELP operator_llm_success_rate Success rate of LLM planning
      # TYPE operator_llm_success_rate gauge
      operator_llm_success_rate #{rand(85..98) / 100.0}
      
      # HELP operator_control_plan_fallback_rate Rate of control plan fallbacks
      # TYPE operator_control_plan_fallback_rate gauge
      operator_control_plan_fallback_rate #{rand(2..15) / 100.0}
      
      # HELP operator_authentication_failures_total Total authentication failures
      # TYPE operator_authentication_failures_total counter
      operator_authentication_failures_total #{rand(0..10)}
      
      # HELP operator_schema_validation_errors_total Total schema validation errors
      # TYPE operator_schema_validation_errors_total counter
      operator_schema_validation_errors_total #{rand(0..5)}
    METRICS
  end
end
