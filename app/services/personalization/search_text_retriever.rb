# frozen_string_literal: true
module Personalization
  class SearchTextRetriever
    include ActiveSupport::Configurable
    
    # Configuration
    config_accessor :max_results, :fuzzy_threshold, :bm25_weight, :vector_weight
    
    # Default configuration
    configure do |config|
      config.max_results = 100
      config.fuzzy_threshold = 0.3
      config.bm25_weight = 0.7
      config.vector_weight = 0.3
    end
    
    def initialize(query:, filters: {}, limit: max_results)
      @query = query.to_s.strip.downcase
      @filters = filters.symbolize_keys
      @limit = limit
      @results = []
    end
    
    def search
      return [] if @query.blank?
      
      # Perform hybrid search: BM25 + fuzzy matching + vector similarity
      bm25_results = perform_bm25_search
      fuzzy_results = perform_fuzzy_search
      vector_results = perform_vector_search
      
      # Combine and rank results
      @results = combine_results(bm25_results, fuzzy_results, vector_results)
      
      # Apply filters and final ranking
      apply_filters
      final_ranking
      
      @results.first(@limit)
    end
    
    private
    
    def perform_bm25_search
      # Simplified text search using ILIKE for demo purposes
      # In production, this would use proper full-text search
      base_query = Product.joins(:shop)
                          .where(moderation_status: 'approved')
                          .where("stock > 0")
      
      # Simple text matching on name and description
      search_terms = @query.split(/\s+/).reject(&:blank?)
      
      # Build ILIKE conditions for each term
      conditions = search_terms.map do |term|
        "(products.name ILIKE ? OR products.description ILIKE ?)"
      end.join(' AND ')
      
      # Create parameter array for ILIKE conditions
      params = search_terms.flat_map { |term| ["%#{term}%", "%#{term}%"] }
      
      # Simple search without complex ranking for now
      base_query
        .where(conditions, *params)
        .limit(@limit * 2) # Get more results for ranking
    end
    
    def perform_fuzzy_search
      return [] if @query.length < 3
      
      # Simplified fuzzy search using ILIKE with wildcards
      base_query = Product.joins(:shop)
                          .where(moderation_status: 'approved')
                          .where("stock > 0")
      
      # Fuzzy search using partial matches
      base_query
        .select("products.*, 0.6 as similarity_score")
        .where("products.name ILIKE ? OR products.description ILIKE ?", 
               "%#{@query}%", "%#{@query}%")
        .order('similarity_score DESC')
        .limit(@limit)
    end
    
    def perform_vector_search
      # This would integrate with your vector search system
      # For now, return empty array as placeholder
      []
    end
    
    def combine_results(bm25_results, fuzzy_results, vector_results)
      combined = []
      
      # Add BM25 results with their ranking
      bm25_results.each do |result|
        combined << {
          product: result,
          score: 1.0, # Simple score for demo
          source: :bm25,
          original_rank: 1.0
        }
      end
      
      # Add fuzzy results with their similarity scores
      fuzzy_results.each do |result|
        combined << {
          product: result,
          score: 0.6, # Simple score for demo
          source: :fuzzy,
          original_rank: 0.6
        }
      end
      
      # Add vector results (placeholder)
      vector_results.each do |result|
        combined << {
          product: result,
          score: result.respond_to?(:vector_score) ? result.vector_score : 0.0,
          source: :vector,
          original_rank: result.respond_to?(:vector_score) ? result.vector_score : 0.0
        }
      end
      
      # Remove duplicates by product ID
      combined.uniq { |r| r[:product].id }
    end
    
    def apply_filters
      return if @filters.empty?
      
      @results.select! do |result|
        product = result[:product]
        
        # Apply category filter
        if @filters[:category_id] && product.category_id != @filters[:category_id]
          next false
        end
        
        # Apply price range filter
        if @filters[:min_price] && product.price_cents < @filters[:min_price]
          next false
        end
        
        if @filters[:max_price] && product.price_cents > @filters[:max_price]
          next false
        end
        
        # Apply shop filter
        if @filters[:shop_id] && product.shop_id != @filters[:shop_id]
          next false
        end
        
        # Apply pickup ready filter
        if @filters[:pickup_ready] && !product.pickup_ready?
          next false
        end
        
        true
      end
    end
    
    def final_ranking
      @results.each do |result|
        # Normalize scores to 0-1 range
        normalized_score = normalize_score(result[:original_rank], result[:source])
        
        # Apply source-specific weights
        weighted_score = apply_source_weights(normalized_score, result[:source])
        
        # Apply business logic adjustments
        business_score = apply_business_logic(result[:product], weighted_score)
        
        result[:final_score] = business_score
      end
      
      # Sort by final score
      @results.sort_by! { |r| -r[:final_score] }
    end
    
    def normalize_score(score, source)
      case source
      when :bm25
        # BM25 scores are typically 0-1, but can be higher
        [score, 1.0].min
      when :fuzzy
        # Similarity scores are 0-1
        score
      when :vector
        # Vector similarity scores are typically 0-1
        score
      else
        0.0
      end
    end
    
    def apply_source_weights(score, source)
      case source
      when :bm25
        score * bm25_weight
      when :fuzzy
        score * (1.0 - bm25_weight) * 0.5
      when :vector
        score * vector_weight
      else
        score
      end
    end
    
    def apply_business_logic(product, score)
      # Boost popular items
      if product.respond_to?(:view_count) && product.view_count.to_i > 100
        score *= 1.1
      end
      
      # Boost items with good ratings
      if product.respond_to?(:rating) && product.rating.to_f > 4.0
        score *= 1.05
      end
      
      # Boost items with recent activity
      if product.respond_to?(:updated_at) && product.updated_at > 1.week.ago
        score *= 1.02
      end
      
      # Penalize items with low stock
      if product.stock < 5
        score *= 0.95
      end
      
      score
    end
    
    def log_search_metrics(query, results_count, duration)
      Rails.logger.info(
        "[SearchTextRetriever] Query: '#{query}' returned #{results_count} results in #{duration.round(3)}s"
      )
      
      # Track search performance metrics
      Personalization::CostMeter.track_search!(
        plan_id: 'search_v1',
        query_length: query.length,
        results_count: results_count,
        duration_ms: (duration * 1000).round
      )
    end
  end
end


