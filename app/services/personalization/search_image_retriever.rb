# frozen_string_literal: true
module Personalization
  class SearchImageRetriever
    # Returns candidate hashes [{ id:, vec_score:, weight:, role:, matched_phrase: }]
    def self.call(image_url:, constraints:, limit: 100, plan_id: 'unknown')
      return [] if image_url.to_s.strip.empty?
      raise ArgumentError, "image_url host not allowed" unless ImageEmbedder.allowed_host?(image_url)

      start_time = Time.current
      cache_hit = false
      
      begin
        # Check if embedding is cached
        cache_key = ImageEmbedder.send(:build_cache_key, image_url)
        cached_embedding = ImageEmbedder.send(:get_cached_embedding, cache_key)
        cache_hit = !cached_embedding.nil?
        
        # Get embedding (cached or fresh)
        vector = cached_embedding || ImageEmbedder.embed_image(image_url)
        
        # Perform vector search
        candidates = VectorSearch.by_vector(vector: vector, limit: limit, constraints: constraints)
        results = candidates.map { |c| c.merge(weight: 1.0, role: "image_search", matched_phrase: "image_query") }
        
        # Track performance
        duration_ms = ((Time.current - start_time) * 1000).round(2)
        ImageSearchPerformance.track_search!(
          image_url: image_url,
          plan_id: plan_id,
          results_count: results.length,
          cache_hit: cache_hit,
          duration_ms: duration_ms
        )
        
        results
        
      rescue => e
        # Track failed search
        duration_ms = ((Time.current - start_time) * 1000).round(2)
        Rails.logger.error "Image search failed for #{ImageEmbedder.send(:mask_url, image_url)}: #{e.message}"
        
        ImageSearchPerformance.track_search!(
          image_url: image_url,
          plan_id: plan_id,
          results_count: 0,
          cache_hit: cache_hit,
          duration_ms: duration_ms
        )
        
        # Return empty results on failure (graceful degradation)
        []
      end
    end
    
    def self.performance_report(timeframe: 1.hour)
      ImageSearchPerformance.performance_report(timeframe: timeframe)
    end
    
    def self.cache_hit_rate(timeframe: 1.hour)
      ImageSearchPerformance.cache_hit_rate(timeframe: timeframe)
    end
  end
end


