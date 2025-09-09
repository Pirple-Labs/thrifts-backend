# frozen_string_literal: true

module Personalization
  class Guardrails
    def self.apply(candidates, context)
      filtered = candidates.select do |item|
        product = Product.includes(:shop).find_by(id: item[:id])
        next false unless product
        
        # Safety checks
        product.stock > 0 &&
        product.moderation_status == "approved" &&
        region_match?(product, context[:snapshot][:region]) &&
        price_band_fit?(product, context[:profile][:price_band]) &&
        !recently_purchased?(product, context[:snapshot][:user_id])
        # merchant_cap_respected?(product, context[:merchant_counts] || {})  # Commented out for dev - few merchants
      end
      
      # Track what was dropped and why
      drop_reasons = analyze_drops(candidates, filtered, context)
      
      { filtered: filtered, drop_reasons: drop_reasons }
    end
    
    private
    
    def self.price_band_fit?(product, price_band)
      return true if price_band.blank?
      
      case price_band
      when "low" then product.price <= 200    # More realistic low price band
      when "mid" then product.price <= 1000  # More realistic mid price band  
      when "high" then product.price > 1000   # More realistic high price band
      else true
      end
    end
    
    def self.recently_purchased?(product, user_id)
      return false unless user_id.present?
      
      # Check if user bought this product in last 30 days
      Order.joins(:order_items)
           .where(user_id: user_id)
           .where("order_items.product_id = ?", product.id)
           .where("orders.created_at >= ?", 30.days.ago)
           .exists?
    end
    
    def self.merchant_cap_respected?(product, merchant_counts)
      # Respect per-merchant limits (max 2 items per merchant per viewport)
      current_count = merchant_counts[product.shop_id] || 0
      current_count < 2
    end
    
    def self.analyze_drops(candidates, filtered, context)
      dropped = candidates - filtered
      reasons = {}
      
      dropped.each do |item|
        product = Product.find_by(id: item[:id])
        next unless product
        
        reason = determine_drop_reason(product, context)
        reasons[reason] = (reasons[reason] || 0) + 1
      end
      
      reasons
    end
    
    def self.region_match?(product, target_region)
      return true unless target_region.present?
      return true unless product.shop&.location.present?
      
      # Enhanced region matching with geohash proximity
      case target_region
      when "ke"
        # Check if shop is in Kenya using location string or geohash
        location_match = product.shop.location.downcase.include?("kenya") || 
                        product.shop.location.downcase.include?("nairobi") ||
                        product.shop.location.downcase.include?("mombasa") ||
                        product.shop.location.downcase.include?("kisumu") ||
                        product.shop.location.downcase.include?("nakuru")
        
        # Also check geohash prefix for Kenya (approximate)
        geohash_match = product.shop.geohash6.present? && 
                       product.shop.geohash6.start_with?("kz") # Kenya geohash prefix
        
        location_match || geohash_match
      else
        true # Allow all regions for demo
      end
    end
    
    
    def self.determine_drop_reason(product, context)
      if product.stock <= 0
        "out_of_stock"
      elsif product.moderation_status != "approved"
        "not_approved"
      elsif !region_match?(product, context[:snapshot][:region])
        "wrong_region"
      elsif !price_band_fit?(product, context[:profile][:price_band])
        "price_band_mismatch"
      elsif recently_purchased?(product, context[:snapshot][:user_id])
        "recently_purchased"
      # elsif !merchant_cap_respected?(product, context[:merchant_counts] || {})
      #   "merchant_cap_exceeded"  # Commented out for dev - few merchants
      else
        "unknown"
      end
    end
  end
end
