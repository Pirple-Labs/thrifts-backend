module Personalization
  module Retrieval
    class FavoritesRules
      def self.run(filters, knobs, context)
        # For demo purposes, return recent products since we don't have a favorites system yet
        # In production, this would query user's favorited products and return new items in those categories
        
        base_query = Product.joins(:shop)
                           .where("products.stock > 0")
                           .where("products.moderation_status = ?", "approved")
        
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
        
        # For demo, return recent products (simulating new items in user's favorite categories)
        recent_products = base_query.order("products.created_at DESC").limit(50)
        
        recent_products.map do |product|
          {
            id: product.id,
            score: 0.7  # Base score for "new in favorites"
          }
        end
      end
    end
  end
end

