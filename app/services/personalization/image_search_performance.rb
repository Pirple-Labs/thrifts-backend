module Personalization
  class ImageSearchPerformance
    include ActiveSupport::Configurable
    
    class << self
      def track_search!(image_url:, plan_id:, results_count:, cache_hit:, duration_ms:)
        # Track basic metrics
        Personalization::CostMeter.track_image_embed!(
          plan_id: plan_id,
          gpu_seconds: cache_hit ? 0 : (duration_ms / 1000.0 * 0.5), # 0.5s GPU time if not cached
          cpu_seconds: duration_ms / 1000.0 * 0.1 # 0.1s CPU time for search
        )
        
        # Log performance metrics
        Rails.logger.info(
          "[ImageSearch] #{cache_hit ? 'CACHE_HIT' : 'CACHE_MISS'} " \
          "url=#{mask_url(image_url)} results=#{results_count} " \
          "duration=#{duration_ms}ms plan=#{plan_id}"
        )
        
        # Store metrics for monitoring
        store_performance_metrics(
          image_url: image_url,
          plan_id: plan_id,
          results_count: results_count,
          cache_hit: cache_hit,
          duration_ms: duration_ms
        )
      end
      
      def cache_hit_rate(timeframe: 1.hour)
        metrics = get_recent_metrics(timeframe)
        return 0.0 if metrics.empty?
        
        hits = metrics.count { |m| m[:cache_hit] }
        hits.to_f / metrics.length
      end
      
      def average_duration(timeframe: 1.hour, cache_status: nil)
        metrics = get_recent_metrics(timeframe)
        
        if cache_status
          metrics = metrics.select { |m| m[:cache_hit] == cache_status }
        end
        
        return 0.0 if metrics.empty?
        
        total_duration = metrics.sum { |m| m[:duration_ms] }
        total_duration.to_f / metrics.length
      end
      
      def performance_report(timeframe: 1.hour)
        metrics = get_recent_metrics(timeframe)
        
        cache_hits = metrics.count { |m| m[:cache_hit] }
        cache_misses = metrics.length - cache_hits
        
        {
          total_searches: metrics.length,
          cache_hits: cache_hits,
          cache_misses: cache_misses,
          cache_hit_rate: cache_hits.to_f / [metrics.length, 1].max,
          avg_duration_ms: average_duration(timeframe),
          avg_duration_cache_hit_ms: average_duration(timeframe, cache_status: true),
          avg_duration_cache_miss_ms: average_duration(timeframe, cache_status: false),
          avg_results_count: metrics.empty? ? 0 : metrics.sum { |m| m[:results_count] }.to_f / metrics.length,
          timeframe_minutes: (timeframe / 1.minute).round
        }
      end
      
      private
      
      def store_performance_metrics(image_url:, plan_id:, results_count:, cache_hit:, duration_ms:)
        # Store in Rails cache for recent metrics (last hour)
        key = "image_search_metrics:#{Time.current.to_i / 60}" # Per minute bucket
        
        metric = {
          timestamp: Time.current,
          image_url: mask_url(image_url),
          plan_id: plan_id,
          results_count: results_count,
          cache_hit: cache_hit,
          duration_ms: duration_ms
        }
        
        Rails.cache.fetch(key, expires_in: 2.hours) { [] }.tap do |metrics|
          metrics << metric
          Rails.cache.write(key, metrics, expires_in: 2.hours)
        end
      rescue => e
        Rails.logger.warn "Failed to store image search metrics: #{e.message}"
      end
      
      def get_recent_metrics(timeframe)
        now = Time.current
        start_time = now - timeframe
        
        metrics = []
        
        # Collect metrics from minute buckets
        (start_time.to_i / 60..now.to_i / 60).each do |minute_bucket|
          key = "image_search_metrics:#{minute_bucket}"
          bucket_metrics = Rails.cache.read(key) || []
          
          # Filter to exact timeframe
          bucket_metrics.each do |metric|
            if metric[:timestamp] >= start_time
              metrics << metric
            end
          end
        end
        
        metrics
      rescue => e
        Rails.logger.warn "Failed to retrieve image search metrics: #{e.message}"
        []
      end
      
      def mask_url(url)
        # Mask sensitive parts of URL for logging
        return "[invalid]" unless url.is_a?(String)
        
        begin
          uri = URI.parse(url)
          "#{uri.scheme}://#{uri.host}/#{uri.path.split('/').first(3).join('/')}/..."
        rescue
          "[masked]"
        end
      end
    end
  end
end
