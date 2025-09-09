#!/usr/bin/env ruby
# scripts/load_test.rb
# Load testing script for feeds API endpoints

require 'net/http'
require 'json'
require 'benchmark'
require 'concurrent'

class LoadTester
  BASE_URL = 'http://localhost:3000'
  ENDPOINTS = {
    'feeds_start' => '/api/feeds/start',
    'feeds_next' => '/api/feeds/next'
  }

  def initialize(rps:, duration_seconds: 600, error_rate: 0.01)
    @rps = rps
    @duration_seconds = duration_seconds
    @error_rate = error_rate
    @results = []
    @errors = []
    @start_time = Time.now
  end

  def run
    puts "🚀 Starting load test: #{@rps} RPS for #{@duration_seconds} seconds"
    puts "📊 Target endpoints: #{ENDPOINTS.keys.join(', ')}"
    puts "⏰ Started at: #{@start_time}"
    puts "=" * 60

    # Calculate request interval
    interval = 1.0 / @rps
    request_count = @rps * @duration_seconds

    puts "📈 Total requests: #{request_count}"
    puts "⏱️  Request interval: #{interval.round(3)}s"
    puts "=" * 60

    # Start load testing
    start_load_test(interval, request_count)

    # Generate report
    generate_report
  end

  private

  def start_load_test(interval, request_count)
    request_count.times do |i|
      # Simulate error injection
      if rand < @error_rate
        simulate_error_request
      else
        make_request(i)
      end

      # Rate limiting
      sleep(interval) if i < request_count - 1
    end
  end

  def make_request(request_id)
    endpoint = ENDPOINTS['feeds_start']
    payload = generate_test_payload(request_id)

    begin
      response_time = Benchmark.realtime do
        response = make_http_request(endpoint, payload)
        record_result(response, response_time)
      end
    rescue => e
      record_error(e)
    end
  end

  def simulate_error_request
    # Simulate various error conditions
    error_types = [
      -> { raise Net::ReadTimeout.new("Simulated timeout") },
      -> { raise Net::HTTPBadRequest.new("400", "Simulated bad request") },
      -> { raise Net::HTTPServerError.new("500", "Simulated server error") }
    ]

    error_types.sample.call
  rescue => e
    record_error(e)
  end

  def make_http_request(endpoint, payload)
    uri = URI("#{BASE_URL}#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 10
    http.open_timeout = 5

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    http.request(request)
  end

  def generate_test_payload(request_id)
    {
      session_id: "load_test_#{request_id}_#{Time.now.to_i}",
      page: ['home', 'pdp', 'profile', 'cart', 'checkout'].sample,
      region: ['Nairobi', 'Mombasa', 'Kisumu'].sample,
      limit: [12, 24, 48].sample,
      pickup_only: [true, false].sample,
      user_id: rand < 0.3 ? rand(1..1000) : nil
    }
  end

  def record_result(response, response_time)
    @results << {
      status: response.code.to_i,
      response_time: response_time,
      timestamp: Time.now,
      success: response.code.to_i < 400
    }
  end

  def record_error(error)
    @errors << {
      error: error.class.name,
      message: error.message,
      timestamp: Time.now
    }
  end

  def generate_report
    puts "\n" + "=" * 60
    puts "📊 LOAD TEST RESULTS"
    puts "=" * 60

    total_requests = @results.size
    successful_requests = @results.count { |r| r[:success] }
    failed_requests = total_requests - successful_requests
    error_requests = @errors.size

    puts "📈 Request Summary:"
    puts "   Total: #{total_requests}"
    puts "   Successful: #{successful_requests}"
    puts "   Failed: #{failed_requests}"
    puts "   Errors: #{error_requests}"
    puts "   Success Rate: #{((successful_requests.to_f / total_requests) * 100).round(2)}%"

    if @results.any?
      response_times = @results.map { |r| r[:response_time] }
      puts "\n⏱️  Response Time Statistics:"
      puts "   Min: #{(response_times.min * 1000).round(2)}ms"
      puts "   Max: #{(response_times.max * 1000).round(2)}ms"
      puts "   Mean: #{(response_times.sum / response_times.size * 1000).round(2)}ms"
      puts "   P50: #{(percentile(response_times, 50) * 1000).round(2)}ms"
      puts "   P95: #{(percentile(response_times, 95) * 1000).round(2)}ms"
      puts "   P99: #{(percentile(response_times, 99) * 1000).round(2)}ms"
    end

    if @errors.any?
      puts "\n❌ Error Summary:"
      error_counts = @errors.group_by { |e| e[:error] }.transform_values(&:size)
      error_counts.each do |error_type, count|
        puts "   #{error_type}: #{count}"
      end
    end

    puts "\n🎯 Performance Targets:"
    puts "   Target RPS: #{@rps}"
    puts "   Target P95: ≤1000ms"
    puts "   Target Error Rate: <0.5%"
    
    # Check if targets are met
    if @results.any?
      p95 = percentile(@results.map { |r| r[:response_time] }, 95)
      error_rate = (error_requests.to_f / total_requests) * 100
      
      puts "\n✅ Target Validation:"
      puts "   P95 ≤1000ms: #{p95 <= 1.0 ? 'PASS' : 'FAIL'} (#{(p95 * 1000).round(2)}ms)"
      puts "   Error Rate <0.5%: #{error_rate < 0.5 ? 'PASS' : 'FAIL'} (#{error_rate.round(3)}%)"
    end

    puts "\n⏰ Test completed at: #{Time.now}"
    puts "⏱️  Total duration: #{Time.now - @start_time} seconds"
  end

  def percentile(array, percentile)
    sorted = array.sort
    index = (percentile / 100.0 * (sorted.length - 1)).round
    sorted[index]
  end
end

# CLI interface
if __FILE__ == $0
  rps = ARGV[0]&.to_i || 100
  duration = ARGV[1]&.to_i || 600

  puts "🔧 Load Test Configuration:"
  puts "   RPS: #{rps}"
  puts "   Duration: #{duration} seconds"
  puts "   Press Ctrl+C to stop early"
  puts "=" * 60

  begin
    tester = LoadTester.new(rps: rps, duration_seconds: duration)
    tester.run
  rescue Interrupt
    puts "\n⏹️  Load test interrupted by user"
    exit 0
  rescue => e
    puts "\n💥 Load test failed: #{e.message}"
    puts e.backtrace.first(5)
    exit 1
  end
end
