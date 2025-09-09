# frozen_string_literal: true

module Personalization
  module Retrieval
    class SearchFusion
      def self.run(filters, knobs, context)
        # Check if this is a search query (has search_term)
        if filters[:search_term].present?
          # Use SearchTextRetriever for proper text search
          search_retriever = Personalization::SearchTextRetriever.new(
            query: filters[:search_term],
            filters: filters,
            limit: knobs[:limit] || 100
          )
          
          text_results = search_retriever.search
          
          # Convert to expected format
          results = text_results.map do |result|
            {
              id: result[:id],
              score: result[:score] || result[:search_rank] || 1.0,
              matched_phrase: result[:matched_phrase] || filters[:search_term],
              role: "text_search"
            }
          end
        else
          # Fallback to original BM25 + ANN fusion
          bm25_results = bm25_search(filters, context)
          ann_results = vector_search(filters, context)
          
          # Combine using alpha_rrf knob
          fused_results = reciprocal_rank_fusion(
            bm25_results, 
            ann_results, 
            alpha: knobs[:alpha_rrf] || 0.6
          )
          
          results = fused_results
        end
        
        # Apply diversity with lambda_diversity knob
        diverse_results = mmr_diversify(
          results, 
          lambda_param: knobs[:lambda_diversity] || 0.3
        )
        
        # Apply price tilt with beta_price_tilt knob
        price_adjusted = apply_price_tilt(
          diverse_results, 
          user_price_band: context[:profile][:price_band],
          beta: knobs[:beta_price_tilt] || 0.2
        )
        
        # Apply proximity scoring to prioritize closer merchants
        proximity_adjusted = apply_proximity_scoring(
          price_adjusted,
          context[:snapshot][:region]
        )
        
        proximity_adjusted
      end
      
      private
      
      def self.bm25_search(filters, context)
        # Text-based search using PostgreSQL full-text search
        # Simplified for demo - in real implementation would use full-text search
        base_query = Product.joins(:shop)
                           .where("products.stock > 0")
                           .where("products.moderation_status = ?", "approved")
        
        # Apply region filter based on shop location
        if filters[:region].present?
          # Enhanced region filtering with geohash proximity
          case filters[:region]
          when "ke"
            base_query = base_query.where(
              "shops.location ILIKE ? OR shops.location ILIKE ? OR shops.location ILIKE ? OR shops.location ILIKE ? OR shops.location ILIKE ? OR shops.location IS NULL OR shops.geohash6 LIKE ?",
              "%kenya%", "%nairobi%", "%mombasa%", "%kisumu%", "%nakuru%", "kz%"
            )
          end
        end
        
        # All products use pickup mtaani delivery - no filtering needed
        
        # Apply price band filter
        if filters[:price_band].present?
          case filters[:price_band]
          when "low"
            base_query = base_query.where("products.price <= 200")
          when "mid"
            base_query = base_query.where("products.price <= 1000")
          when "high"
            base_query = base_query.where("products.price > 1000")
          end
        end
        
        # Apply freshness filter
        if filters[:fresh_days].present? && filters[:fresh_days] > 0
          base_query = base_query.where("products.created_at >= ?", filters[:fresh_days].days.ago)
        end
        
        base_query.limit(100)
      end
      
      def self.vector_search(filters, context)
        # Semantic search using pgvector
        return [] unless context[:session_embed_summary]&.dig(:centroid_hash)
        
        # This would use the actual embedding vector for similarity search
        # For now, return a subset of products as placeholder
        base_query = Product.joins(:shop)
                           .where("products.stock > 0")
                           .where("products.moderation_status = ?", "approved")
        
        # Apply same filters as BM25
        if filters[:price_band].present?
          case filters[:price_band]
          when "low"
            base_query = base_query.where("products.price <= 200")
          when "mid"
            base_query = base_query.where("products.price <= 1000")
          when "high"
            base_query = base_query.where("products.price > 1000")
          end
        end
        
        if filters[:fresh_days].present? && filters[:fresh_days] > 0
          base_query = base_query.where("products.created_at >= ?", filters[:fresh_days].days.ago)
        end
        
        base_query.limit(100)
      end
      
      def self.build_bm25_query(filters)
        # Build search query from filters
        terms = []
        
        if filters[:categories].present?
          terms += filters[:categories]
        end
        
        if filters[:search_term].present?
          terms << filters[:search_term]
        end
        
        terms.any? ? terms.join(" ") : "trending"
      end
      
      def self.reciprocal_rank_fusion(bm25_results, ann_results, alpha: 0.6)
        scores = {}
        
        bm25_results.each_with_index do |item, rank|
          scores[item.id] ||= 0
          scores[item.id] += (1.0 / (rank + 1)) * alpha
        end
        
        ann_results.each_with_index do |item, rank|
          scores[item.id] ||= 0
          scores[item.id] += (1.0 / (rank + 1)) * (1 - alpha)
        end
        
        # Convert to array of hashes with scores
        scores.map { |id, score| { id: id, score: score } }
              .sort_by { |item| -item[:score] }
      end
      
      def self.mmr_diversify(results, lambda_param: 0.3)
        return results if results.empty?
        
        selected = []
        remaining = results.dup
        
        # Always include the top result
        selected << remaining.shift if remaining.any?
        
        while selected.size < [results.size, 50].min && remaining.any?
          best_item = remaining.max_by do |item|
            # Relevance score
            relevance = item[:score] || 0
            
            # Diversity penalty (simplified - would use actual similarity)
            diversity_penalty = if selected.any?
              selected.map do |selected_item|
                # Simplified similarity based on product ID difference
                1.0 / (1.0 + (item[:id] - selected_item[:id]).abs / 1000.0)
              end.max || 0
            else
              0
            end
            
            # MMR score
            lambda_param * item[:score] - (1 - lambda_param) * diversity_penalty
          end
          
          selected << best_item
          remaining.delete(best_item)
        end
        
        selected
      end
      
      def self.apply_price_tilt(results, user_price_band:, beta: 0.2)
        return results if user_price_band.blank?
        
        results.map do |item|
          product = Product.find_by(id: item[:id])
          next item unless product
          
          price_score = case user_price_band
          when "low"
            1.0 / (1.0 + product.price / 100.0)
          when "mid"
            1.0 / (1.0 + (product.price - 250).abs / 100.0)
          when "high"
            1.0 / (1.0 + 1000.0 / [product.price, 1].max)
          else
            1.0
          end
          
          item[:score] = (item[:score] || 0) * (1 - beta) + price_score * beta
          item
        end
      end
      
      def self.apply_proximity_scoring(results, target_region)
        return results unless target_region.present?
        
        results.map do |item|
          product = Product.includes(:shop).find_by(id: item[:id])
          next item unless product&.shop
          
          proximity_score = calculate_proximity_score(product, target_region)
          item[:score] = (item[:score] || 0) + proximity_score
          item
        end.compact
      end
      
      def self.calculate_proximity_score(product, target_region)
        return 0 unless product.shop&.location.present?
        
        case target_region
        when "ke"
          # Boost score for major Kenyan cities (closer to user)
          location = product.shop.location.downcase
          
          if location.include?("nairobi")
            0.3  # Highest boost for Nairobi (likely most users)
          elsif location.include?("mombasa")
            0.2  # High boost for Mombasa
          elsif location.include?("kisumu") || location.include?("nakuru")
            0.15 # Medium boost for other major cities
          elsif location.include?("kenya")
            0.1  # Base boost for Kenya
          else
            0.05 # Small boost for other locations
          end
        else
          0
        end
      end
    end
  end
end
