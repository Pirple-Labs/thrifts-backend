# frozen_string_literal: true

module Personalization
  module Retrieval
    class Lookalikes
      def self.run(filters, knobs, context)
        # Find products similar to user's recent interactions
        recent_products = get_recent_products(context)
        return [] if recent_products.empty?
        
        # Find similar products using embeddings or co-purchase patterns
        similar_products = find_similar_products(recent_products, filters, knobs)
        
        # Apply diversity and ranking
        diverse_results = mmr_diversify(similar_products, lambda_param: knobs[:lambda_diversity] || 0.3)
        
        # Apply price tilt
        price_adjusted = apply_price_tilt(
          diverse_results, 
          user_price_band: context[:profile][:price_band],
          beta: knobs[:beta_price_tilt] || 0.2
        )
        
        price_adjusted
      end
      
      private
      
      def self.get_recent_products(context)
        # Get products from recent user interactions
        user_id = context[:snapshot][:user_id]
        return [] unless user_id.present?
        
        # Get recent product views, cart additions, purchases
        # Simplified for demo - in real implementation would extract product_id from payload
        Product.joins(:shop)
               .where("products.stock > 0")
               .where("products.moderation_status = ?", "approved")
               .limit(10)
      end
      
      def self.find_similar_products(recent_products, filters, knobs)
        # Find products similar to recent products
        similar_products = []
        
        recent_products.each do |product|
          # Find products in same category
          category_similar = Product.joins(:shop)
                                  .where(category: product.category)
                                  .where.not(id: product.id)
                                  .where("products.stock > 0")
                                  .where("products.moderation_status = ?", "approved")
                                  .limit(5)
          
          # Find products with similar price range
          price_range = product.price * 0.5..product.price * 1.5
          price_similar = Product.joins(:shop)
                               .where(price: price_range)
                               .where.not(id: product.id)
                               .where("products.stock > 0")
                               .where("products.moderation_status = ?", "approved")
                               .limit(3)
          
          # Find products from same brand
          brand_similar = Product.joins(:shop)
                               .where(brand: product.brand)
                               .where.not(id: product.id)
                               .where("products.stock > 0")
                               .where("products.moderation_status = ?", "approved")
                               .limit(3)
          
          similar_products.concat(category_similar.to_a)
          similar_products.concat(price_similar.to_a)
          similar_products.concat(brand_similar.to_a)
        end
        
        # Remove duplicates and add scores
        similar_products.uniq.map do |product|
          {
            id: product.id,
            score: calculate_similarity_score(product, recent_products)
          }
        end.sort_by { |item| -item[:score] }
      end
      
      def self.calculate_similarity_score(product, recent_products)
        score = 0.0
        
        recent_products.each do |recent_product|
          # Category similarity
          if product.category == recent_product.category
            score += 0.4
          end
          
          # Price similarity
          price_diff = (product.price - recent_product.price).abs
          price_similarity = 1.0 / (1.0 + price_diff / 100.0)
          score += price_similarity * 0.3
          
          # Brand similarity
          if product.brand == recent_product.brand
            score += 0.3
          end
        end
        
        score
      end
      
      def self.mmr_diversify(results, lambda_param: 0.3)
        return results if results.empty?
        
        selected = []
        remaining = results.dup
        
        # Always include the top result
        selected << remaining.shift if remaining.any?
        
        while selected.size < [results.size, 20].min && remaining.any?
          best_item = remaining.max_by do |item|
            # Relevance score
            relevance = item[:score] || 0
            
            # Diversity penalty (simplified)
            diversity_penalty = if selected.any?
              selected.map do |selected_item|
                # Simplified similarity based on product ID difference
                1.0 / (1.0 + (item[:id] - selected_item[:id]).abs / 1000.0)
              end.max || 0
            else
              0
            end
            
            # MMR score
            lambda_param * relevance - (1 - lambda_param) * diversity_penalty
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
    end
  end
end
