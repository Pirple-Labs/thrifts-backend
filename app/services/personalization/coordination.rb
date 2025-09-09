# frozen_string_literal: true

module Personalization
  class Coordination
    def self.fill_if_applicable(items, section, snapshot, profile, session_embed_summary = {})
      # Enhanced coordination logic using new services
      
      case section[:id]
      when "complete_the_look"
        # Use new Complements service
        Personalization::Retrieval::Complements.run(section, snapshot, profile, session_embed_summary)
      when "bundle_and_save"
        # Use BundleBuilder service
        build_bundle_section(section, snapshot, profile)
      when "use_case_completion"
        # Use UseCaseCompletion service
        Personalization::Retrieval::UseCaseCompletion.run(section, snapshot, profile, session_embed_summary)
      when "more_from_shop"
        # Find products from the same shop
        find_shop_items(items, snapshot, profile)
      when "new_in_favorites"
        # Find recently added products
        find_recent_items(snapshot, profile)
      when "from_shops_you_like"
        # Find products from preferred shops
        find_preferred_shop_items(snapshot, profile)
      else
        items
      end
    end
    
    private
    
    def self.build_bundle_section(section, snapshot, profile)
      # Get seed products for bundle building
      seed_products = get_seed_products_for_bundle(snapshot)
      return [] if seed_products.empty?

      # Build bundle using BundleBuilder
      bundle_result = Personalization::BundleBuilder.build(
        seed_products: seed_products,
        template_hint: section[:hints]&.dig('template_hint'),
        region: snapshot[:region],
        count: section[:count] || 4
      )

      return [] unless bundle_result

      # Return products with bundle metadata
      bundle_result[:products].map do |product_data|
        {
          id: product_data[:id],
          score: product_data[:score],
          role: product_data[:role],
          bundle_slot: product_data[:bundle_slot],
          bundle_id: bundle_result[:bundle_id],
          bundle_pricing: bundle_result[:pricing]
        }
      end
    end

    def self.get_seed_products_for_bundle(snapshot)
      case snapshot[:page]
      when 'pdp'
        if snapshot[:pid]
          product = Product.find_by(id: snapshot[:pid])
          return [product] if product
        end
      when 'cart', 'checkout'
        # In real implementation, would get from cart service
        return Product.limit(2)
      end
      
      # Fallback to recent products
      Product.limit(1)
    end
    
    def self.find_complementary_items(items, snapshot, profile)
      # Find products that complement existing items
      # For demo, return some random products
      Product.joins(:shop)
             .where("products.stock > 0")
             .where("products.moderation_status = ?", "approved")
             .limit(6)
             .map { |p| { id: p.id, score: 0.8 } }
    end
    
    def self.find_shop_items(items, snapshot, profile)
      # Find products from the same shop as existing items
      # For demo, return some random products
      Product.joins(:shop)
             .where("products.stock > 0")
             .where("products.moderation_status = ?", "approved")
             .limit(8)
             .map { |p| { id: p.id, score: 0.7 } }
    end
    
    def self.find_recent_items(snapshot, profile)
      # Find recently added products
      # For demo, return some random products (removed freshness filter)
      Product.joins(:shop)
             .where("products.stock > 0")
             .where("products.moderation_status = ?", "approved")
             .limit(12)
             .map { |p| { id: p.id, score: 0.6 } }
    end
    
    def self.find_preferred_shop_items(snapshot, profile)
      # Find products from preferred shops
      # For demo, return some random products
      Product.joins(:shop)
             .where("products.stock > 0")
             .where("products.moderation_status = ?", "approved")
             .limit(12)
             .map { |p| { id: p.id, score: 0.5 } }
    end
    
    def self.find_coordinating_items(items, slot, weights, context:)
      # Find products that coordinate with existing items
      case slot
      when "shoes"
        find_shoes_for_outfit(items, weights, context)
      when "bag"
        find_bags_for_outfit(items, weights, context)
      when "accessories"
        find_accessories_for_tech(items, weights, context)
      when "complementary"
        find_complementary_items(items, weights, context)
      else
        find_generic_coordinating_items(items, slot, weights, context)
      end
    end
    
    def self.find_shoes_for_outfit(items, weights, context:)
      # Find shoes that match the style/color of clothing items
      clothing_items = items.select { |item| 
        product = Product.find_by(id: item[:id])
        product&.category&.name == "Fashion"
      }
      return [] if clothing_items.empty?
      
      # Use embedding similarity + co-purchase patterns
      shoes = Product.where(category: Category.find_by(name: "Fashion"))
                    .where(subcategory: "Footwear")
                    .where(region: context[:snapshot][:region])
                    .where(pickup_only: context[:snapshot][:pickup_only])
                    .where("stock > 0")
                    .where(moderation_status: "approved")
      
      shoes.map do |shoe|
        # Calculate coordination score
        emb_score = embedding_similarity(shoe, clothing_items) * weights[:emb]
        copurch_score = copurchase_score(shoe, clothing_items) * weights[:copurch]
        attr_score = attribute_match(shoe, clothing_items) * weights[:attr]
        profile_score = profile_fit(shoe, context[:profile]) * weights[:profile]
        
        total_score = emb_score + copurch_score + attr_score + profile_score
        
        { product: shoe, score: total_score }
      end.sort_by { |item| -item[:score] }.take(3)
    end
    
    def self.find_bags_for_outfit(items, weights, context:)
      # Find bags that coordinate with clothing items
      clothing_items = items.select { |item| 
        product = Product.find_by(id: item[:id])
        product&.category&.name == "Fashion"
      }
      return [] if clothing_items.empty?
      
      bags = Product.where(category: Category.find_by(name: "Fashion"))
                   .where(subcategory: "Bags")
                   .where(region: context[:snapshot][:region])
                   .where(pickup_only: context[:snapshot][:pickup_only])
                   .where("stock > 0")
                   .where(moderation_status: "approved")
      
      bags.map do |bag|
        emb_score = embedding_similarity(bag, clothing_items) * weights[:emb]
        copurch_score = copurchase_score(bag, clothing_items) * weights[:copurch]
        attr_score = attribute_match(bag, clothing_items) * weights[:attr]
        profile_score = profile_fit(bag, context[:profile]) * weights[:profile]
        
        total_score = emb_score + copurch_score + attr_score + profile_score
        
        { product: bag, score: total_score }
      end.sort_by { |item| -item[:score] }.take(3)
    end
    
    def self.find_accessories_for_tech(items, weights, context:)
      # Find accessories that work with tech products
      tech_items = items.select { |item| 
        product = Product.find_by(id: item[:id])
        product&.category&.name == "Electronics"
      }
      return [] if tech_items.empty?
      
      accessories = Product.where(category: Category.find_by(name: "Electronics"))
                          .where(subcategory: ["Peripherals", "Audio"])
                          .where(region: context[:snapshot][:region])
                          .where(pickup_only: context[:snapshot][:pickup_only])
                          .where("stock > 0")
                          .where(moderation_status: "approved")
      
      accessories.map do |accessory|
        emb_score = embedding_similarity(accessory, tech_items) * weights[:emb]
        copurch_score = copurchase_score(accessory, tech_items) * weights[:copurch]
        attr_score = attribute_match(accessory, tech_items) * weights[:attr]
        profile_score = profile_fit(accessory, context[:profile]) * weights[:profile]
        
        total_score = emb_score + copurch_score + attr_score + profile_score
        
        { product: accessory, score: total_score }
      end.sort_by { |item| -item[:score] }.take(3)
    end
    
    def self.find_complementary_items(items, snapshot, profile)
      # Generic complementary item finder
      base_items = items.map { |item| Product.find_by(id: item[:id]) }.compact
      return [] if base_items.empty?
      
      # Find products in different categories that complement the base items
      complementary = Product.joins(:shop)
                            .where.not(category: base_items.map(&:category).uniq)
                            .where("products.stock > 0")
                            .where("products.moderation_status = ?", "approved")
                            .limit(20)
      
      complementary.map do |product|
        # Simplified scoring for demo - in production would use sophisticated algorithms
        base_score = 0.5
        
        # Boost for products in popular price ranges
        if product.price >= 50 && product.price <= 300
          base_score += 0.3
        end
        
        # Boost for products from major cities
        if product.shop&.location&.downcase&.include?("nairobi")
          base_score += 0.2
        end
        
        { id: product.id, score: base_score }
      end.sort_by { |item| -item[:score] }.take(3)
    end
    
    def self.find_generic_coordinating_items(items, slot, weights, context:)
      # Generic coordination for any slot type
      base_items = items.map { |item| Product.find_by(id: item[:id]) }.compact
      return [] if base_items.empty?
      
      # Find products that coordinate based on general similarity
      coordinating = Product.where(region: context[:snapshot][:region])
                           .where(pickup_only: context[:snapshot][:pickup_only])
                           .where("stock > 0")
                           .where(moderation_status: "approved")
                           .limit(20)
      
      coordinating.map do |product|
        emb_score = embedding_similarity(product, base_items) * weights[:emb]
        copurch_score = copurchase_score(product, base_items) * weights[:copurch]
        attr_score = attribute_match(product, base_items) * weights[:attr]
        profile_score = profile_fit(product, context[:profile]) * weights[:profile]
        
        total_score = emb_score + copurch_score + attr_score + profile_score
        
        { id: product.id, score: total_score }
      end.sort_by { |item| -item[:score] }.take(3)
    end
    
    def self.embedding_similarity(product, base_items)
      # Simplified embedding similarity (would use actual embeddings)
      # For now, use category and brand similarity
      category_matches = base_items.count { |item| item.category == product.category }
      brand_matches = base_items.count { |item| item.brand == product.brand }
      
      (category_matches * 0.6 + brand_matches * 0.4) / base_items.size.to_f
    end
    
    def self.copurchase_score(product, base_items)
      # Simplified co-purchase score (would use actual co-purchase data)
      # For now, return a random score between 0.1 and 0.9
      rand(0.1..0.9)
    end
    
    def self.attribute_match(product, base_items)
      # Simplified attribute matching
      # For now, use price range similarity
      base_avg_price = base_items.map(&:price).sum / base_items.size.to_f
      price_diff = (product.price - base_avg_price).abs
      price_similarity = 1.0 / (1.0 + price_diff / 100.0)
      
      price_similarity
    end
    
    def self.profile_fit(product, profile)
      # Check how well product fits user profile
      score = 0.0
      
      # Price band fit
      if profile[:price_band] == "low" && product.price <= 100
        score += 0.3
      elsif profile[:price_band] == "mid" && product.price <= 500
        score += 0.3
      elsif profile[:price_band] == "high" && product.price > 500
        score += 0.3
      end
      
      # Category preference
      if profile[:top_categories].include?(product.category&.name)
        score += 0.4
      end
      
      # Brand preference
      if profile[:brand_top].include?(product.brand&.name)
        score += 0.3
      end
      
      score
    end
    
    def self.apply_coordination_caps(coordinated_items, caps)
      # Apply per-merchant and per-viewport caps
      merchant_counts = {}
      viewport_count = 0
      
      coordinated_items.select do |item|
        product = item[:product]
        
        # Check merchant cap
        merchant_count = merchant_counts[product.shop_id] || 0
        next false if merchant_count >= (caps[:per_merchant] || 2)
        
        # Check viewport cap
        next false if viewport_count >= (caps[:per_viewport] || 2)
        
        # Update counts
        merchant_counts[product.shop_id] = merchant_count + 1
        viewport_count += 1
        
        true
      end
    end
  end
end
