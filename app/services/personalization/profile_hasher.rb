# frozen_string_literal: true

module Personalization
  class ProfileHasher
    def self.hash(snapshot, profile)
      # Quantize profile into bits for cache key
      bits = []
      
      # Price band (2 bits)
      bits << encode_price_band(profile[:price_band])
      
      # Top categories (5 bits each, max 3 categories)
      bits << encode_categories((profile[:top_categories] || []).take(3))
      
      # Top brands (3 bits each, max 2 brands)
      bits << encode_brands((profile[:brand_top] || []).take(2))
      
      # Preferences (quantized to 4 bits each)
      bits << quantize_preference(profile[:freshness_pref])
      bits << quantize_preference(profile[:diversity_pref])
      
      # Region and pickup (2 bits)
      bits << encode_region_pickup(snapshot[:region], snapshot[:pickup_only])
      
      bits.join("_")
    end
    
    private
    
    def self.encode_price_band(price_band)
      case price_band
      when "low" then "00"
      when "mid" then "01"
      when "high" then "10"
      else "11"  # unknown
      end
    end
    
    def self.encode_categories(categories)
      # Map categories to 5-bit codes
      category_codes = {
        "Electronics" => "00000",
        "Beauty" => "00001",
        "Fashion" => "00010",
        "Home" => "00011",
        "Sports" => "00100",
        "Books" => "00101",
        "Health" => "00110",
        "Automotive" => "00111"
      }
      
      categories.map { |cat| category_codes[cat] || "11111" }.join("_")
    end
    
    def self.encode_brands(brands)
      # Map brands to 3-bit codes (simplified)
      brand_codes = {
        "Apple" => "000",
        "Samsung" => "001",
        "Nike" => "010",
        "Adidas" => "011",
        "Sony" => "100",
        "LG" => "101",
        "Dell" => "110"
      }
      
      brands.map { |brand| brand_codes[brand] || "111" }.join("_")
    end
    
    def self.quantize_preference(pref)
      # Convert 0-1 preference to 4-bit quantized value
      quantized = (pref * 15).round
      quantized.to_s(2).rjust(4, '0')
    end
    
    def self.encode_region_pickup(region, pickup_only)
      # 2 bits: region (1 bit) + pickup (1 bit)
      region_bit = region == "ke" ? "0" : "1"
      pickup_bit = pickup_only ? "1" : "0"
      region_bit + pickup_bit
    end
  end
end

