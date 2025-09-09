# frozen_string_literal: true

module Personalization
  module Retrieval
    class Trending
      def self.run(filters, knobs, context)
        # Find trending products based on recent activity
        trending_products = find_trending_products(filters, knobs)
        
        # Apply diversity
        diverse_results = mmr_diversify(trending_products, lambda_param: knobs[:lambda_diversity] || 0.3)
        
        # Apply price tilt
        price_adjusted = apply_price_tilt(
          diverse_results, 
          user_price_band: context[:profile][:price_band],
          beta: knobs[:beta_price_tilt] || 0.2
        )
        
        price_adjusted
      end
      
      private
      
      def self.find_trending_products(filters, knobs)
        # Calculate trending score based on recent views, cart additions, purchases
        tau_fresh_days = knobs[:tau_fresh_days] || 14
        
        # Get products with recent interaction activity
        # Use actual event data to determine trending products
        trending_product_ids = get_trending_product_ids(tau_fresh_days)
        
        return [] if trending_product_ids.empty?
        
        base_query = Product.joins(:shop)
                           .where("products.stock > 0")
                           .where("products.moderation_status = ?", "approved")
                           .where("products.id IN (?)", trending_product_ids)
        
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
        
        # Freshness filter removed for demo - trending should be based on user interactions, not upload date
        
        trending_products = base_query.order("products.created_at DESC").limit(50)
        
        # Convert to array with scores
        trending_products.map do |product|
          {
            id: product.id,
            score: calculate_trending_score(product, tau_fresh_days)
          }
        end
      end
      
      def self.calculate_trending_score(product, tau_fresh_days)
        # Calculate trending score based on recent interactions
        # Extract product_id from event payloads and calculate weighted score
        
        # Get recent events for this product
        recent_events = Event.where(
          event_name: ["product_view", "add_to_cart", "purchase"],
          timestamp_utc: tau_fresh_days.days.ago..
        ).where("payload->>'product_id' = ?", product.id.to_s)
        
        score = 0.0
        recent_events.each do |event|
          # Time decay factor
          days_ago = (Time.current - event.timestamp_utc) / 1.day
          decay_factor = Math.exp(-days_ago / tau_fresh_days)
          
          # Event weight
          event_weight = case event.event_name
          when "product_view" then 1.0
          when "add_to_cart" then 3.0
          when "purchase" then 10.0
          else 1.0
          end
          
          score += event_weight * decay_factor
        end
        
        # Base score for being a trending product
        base_score = 1.0
        
        # Boost score based on product characteristics
        trending_boost = 0.0
        
        # Boost for products with good stock levels
        if product.stock > 10
          trending_boost += 0.5
        end
        
        # Boost for products in popular price ranges
        if product.price >= 50 && product.price <= 300
          trending_boost += 0.3
        end
        
        # Boost for products from shops in major cities
        if product.shop&.location&.downcase&.include?("nairobi")
          trending_boost += 0.4
        elsif product.shop&.location&.downcase&.include?("mombasa")
          trending_boost += 0.2
        end
        
        # Final trending score
        final_score = (score + base_score + trending_boost) / 10.0
        
        final_score
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
      
      def self.get_trending_product_ids(tau_fresh_days)
        # Get products that have been trending based on recent interactions
        # Extract product_id from event payloads
        
        # In a real implementation, this would analyze:
        # - product_view events (weight: 1)
        # - add_to_cart events (weight: 3) 
        # - purchase events (weight: 10)
        # - search events that led to product views (weight: 2)
        
        # Get recent events and extract product IDs from payloads
        recent_events = Event.where(
          event_name: ["product_view", "add_to_cart", "purchase"],
          timestamp_utc: tau_fresh_days.days.ago..
        ).limit(100)
        
        # Extract product IDs from event payloads
        trending_ids = recent_events.map do |event|
          # Extract product_id from the JSONB payload
          product_id = event.payload["product_id"] || event.payload[:product_id]
          product_id.to_i if product_id.present?
        end.compact.uniq
        
        # If no events with product_ids, fall back to some default trending products
        if trending_ids.empty?
          # Get some products that would be trending (mix of different categories/price ranges)
          trending_products = Product.joins(:shop)
                                   .where("products.stock > 0")
                                   .where("products.moderation_status = ?", "approved")
                                   .order("RANDOM()")  # Random selection to simulate trending
                                   .limit(20)
          trending_ids = trending_products.pluck(:id)
        end
        
        trending_ids
      end
    end
  end
end
