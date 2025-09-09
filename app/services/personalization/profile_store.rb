# frozen_string_literal: true

module Personalization
  class ProfileStore
    def self.slice(user_id)
      return default_profile unless user_id.present?
      
      user = User.find_by(id: user_id)
      return default_profile unless user
      
      {
        price_band: infer_price_band(user),
        top_categories: top_categories(user),
        brand_top: top_brands(user),
        shop_top: top_shops(user),
        freshness_pref: freshness_preference(user),
        diversity_pref: diversity_preference(user)
      }
    end
    
    private
    
    def self.default_profile
      {
        price_band: "mid",
        top_categories: [],
        brand_top: [],
        shop_top: [],
        freshness_pref: 0.5,
        diversity_pref: 0.5
      }
    end
    
    def self.infer_price_band(user)
      # Analyze purchase history to infer price sensitivity
      avg_purchase_price = user.orders
                              .joins(:order_items)
                              .average('order_items.price')
      
      case avg_purchase_price
      when nil, 0..100 then "low"
      when 100..500 then "mid"
      else "high"
      end
    end
    
    def self.top_categories(user)
      # Get most engaged categories from views/purchases
      # Since events don't have direct product association, we'll use a simplified approach
      # In a real implementation, you'd extract product_id from payload and join
      []
    end
    
    def self.top_brands(user)
      # Get preferred brands from purchases
      # Simplified for demo - in real implementation would join through orders
      []
    end
    
    def self.top_shops(user)
      # Get preferred shops from purchases
      # Simplified for demo - in real implementation would join through orders
      []
    end
    
    def self.freshness_preference(user)
      # Calculate how much user likes new items
      # Simplified for demo - in real implementation would analyze product creation dates
      0.5
    end
    
    def self.diversity_preference(user)
      # Calculate preference for variety across categories
      # Simplified for demo - in real implementation would analyze category diversity
      0.5
    end
  end
end
