namespace :product_relationships do
  desc "Seed product relationships for intelligent coordination"
  task seed: :environment do
    puts "Starting product relationships seeding..."
    
    created_count = 0
    error_count = 0
    
    # Electronics relationships
    seed_electronics_relationships
    created_count += 1
    
    # Beauty relationships
    seed_beauty_relationships
    created_count += 1
    
    # Fashion relationships
    seed_fashion_relationships
    created_count += 1
    
    # Home relationships
    seed_home_relationships
    created_count += 1
    
    puts "\n=== Product Relationships Seeding Complete ==="
    puts "Relationship categories created: #{created_count}"
    puts "Errors: #{error_count}"
  end
  
  private
  
  def seed_electronics_relationships
    puts "Seeding electronics relationships..."
    
    # Laptop accessories
    laptops = Product.where(subcategory: "Laptops").limit(10)
    accessories = Product.where(category: Category.find_by(name: "Electronics"))
                        .where("subcategory IN (?)", ["Audio", "Peripherals"])
                        .limit(20)
    
    laptops.each do |laptop|
      accessories.each do |accessory|
        next if laptop.id == accessory.id
        
        create_relationship(
          product: laptop,
          related_product: accessory,
          relationship_type: "complementary",
          strength_score: 0.8,
          context: {
            reason: "laptop_accessory",
            compatibility: "universal",
            use_case: "professional_work"
          }
        )
      end
    end
    
    # Phone accessories
    phones = Product.where(subcategory: "Phones").limit(10)
    phone_accessories = Product.where(category: Category.find_by(name: "Electronics"))
                              .where("subcategory IN (?)", ["Audio", "Peripherals"])
                              .limit(15)
    
    phones.each do |phone|
      phone_accessories.each do |accessory|
        next if phone.id == accessory.id
        
        create_relationship(
          product: phone,
          related_product: accessory,
          relationship_type: "complementary",
          strength_score: 0.9,
          context: {
            reason: "phone_accessory",
            compatibility: "universal",
            use_case: "daily_use"
          }
        )
      end
    end
  end
  
  def seed_beauty_relationships
    puts "Seeding beauty relationships..."
    
    # Skincare routine
    serums = Product.where(subcategory: "Skincare")
                    .where("use_case LIKE ?", "%serum%")
                    .limit(10)
    
    cleansers = Product.where(subcategory: "Skincare")
                      .where("use_case LIKE ?", "%cleanser%")
                      .limit(10)
    
    moisturizers = Product.where(subcategory: "Skincare")
                         .where("use_case LIKE ?", "%moisturizer%")
                         .limit(10)
    
    # Create skincare routine relationships
    serums.each do |serum|
      cleansers.each do |cleanser|
        create_relationship(
          product: serum,
          related_product: cleanser,
          relationship_type: "complementary",
          strength_score: 0.9,
          context: {
            reason: "skincare_routine",
            step_order: "cleanser_before_serum",
            use_case: "daily_skincare"
          }
        )
      end
      
      moisturizers.each do |moisturizer|
        create_relationship(
          product: serum,
          related_product: moisturizer,
          relationship_type: "complementary",
          strength_score: 0.9,
          context: {
            reason: "skincare_routine",
            step_order: "serum_before_moisturizer",
            use_case: "daily_skincare"
          }
        )
      end
    end
    
    # Makeup relationships
    foundations = Product.where(subcategory: "Makeup")
                        .where("use_case LIKE ?", "%foundation%")
                        .limit(10)
    
    brushes = Product.where(subcategory: "Tools")
                    .where("use_case LIKE ?", "%makeup%")
                    .limit(10)
    
    foundations.each do |foundation|
      brushes.each do |brush|
        create_relationship(
          product: foundation,
          related_product: brush,
          relationship_type: "complementary",
          strength_score: 0.8,
          context: {
            reason: "makeup_application",
            compatibility: "universal",
            use_case: "makeup_routine"
          }
        )
      end
    end
  end
  
  def seed_fashion_relationships
    puts "Seeding fashion relationships..."
    
    # Clothing + Accessories
    tops = Product.where(subcategory: "Tops").limit(15)
    bottoms = Product.where(subcategory: "Bottoms").limit(15)
    accessories = Product.where(subcategory: "Accessories").limit(20)
    
    # Top + Bottom combinations
    tops.each do |top|
      bottoms.each do |bottom|
        next if top.id == bottom.id
        
        # Check if they're from same brand or similar style
        if compatible_fashion_items?(top, bottom)
          create_relationship(
            product: top,
            related_product: bottom,
            relationship_type: "complementary",
            strength_score: 0.7,
            context: {
              reason: "outfit_coordination",
              style_match: "compatible",
              use_case: "daily_wear"
            }
          )
        end
      end
      
      # Top + Accessories
      accessories.each do |accessory|
        if compatible_fashion_items?(top, accessory)
          create_relationship(
            product: top,
            related_product: accessory,
            relationship_type: "complementary",
            strength_score: 0.6,
            context: {
              reason: "accessory_coordination",
              style_match: "compatible",
              use_case: "style_enhancement"
            }
          )
        end
      end
    end
    
    # Shoes + Accessories
    shoes = Product.where(subcategory: "Footwear").limit(10)
    shoe_accessories = Product.where(subcategory: "Accessories")
                             .where("use_case LIKE ?", "%shoe%")
                             .limit(10)
    
    shoes.each do |shoe|
      shoe_accessories.each do |accessory|
        create_relationship(
          product: shoe,
          related_product: accessory,
          relationship_type: "complementary",
          strength_score: 0.8,
          context: {
            reason: "shoe_care",
            compatibility: "universal",
            use_case: "footwear_maintenance"
          }
        )
      end
    end
  end
  
  def seed_home_relationships
    puts "Seeding home relationships..."
    
    # Furniture + Decor
    furniture = Product.where(subcategory: "Furniture").limit(15)
    decor = Product.where(subcategory: "Furniture")
                   .where("use_case LIKE ?", "%decor%")
                   .limit(10)
    
    furniture.each do |item|
      decor.each do |decor_item|
        if compatible_home_items?(item, decor_item)
          create_relationship(
            product: item,
            related_product: decor_item,
            relationship_type: "complementary",
            strength_score: 0.7,
            context: {
              reason: "room_coordination",
              style_match: "compatible",
              use_case: "home_decor"
            }
          )
        end
      end
    end
    
    # Kitchen relationships
    kitchen_appliances = Product.where(subcategory: "Kitchen")
                               .where("use_case LIKE ?", "%appliance%")
                               .limit(10)
    
    kitchen_utensils = Product.where(subcategory: "Kitchen")
                             .where("use_case LIKE ?", "%utensil%")
                             .limit(15)
    
    kitchen_appliances.each do |appliance|
      kitchen_utensils.each do |utensil|
        create_relationship(
          product: appliance,
          related_product: utensil,
          relationship_type: "complementary",
          strength_score: 0.8,
          context: {
            reason: "kitchen_functionality",
            compatibility: "universal",
            use_case: "cooking"
          }
        )
      end
    end
  end
  
  def create_relationship(product:, related_product:, relationship_type:, strength_score:, context:)
    # Check if relationship already exists
    existing = ProductRelationship.find_by(
      product_id: product.id,
      related_product_id: related_product.id,
      relationship_type: relationship_type
    )
    
    return if existing
    
    # Create the relationship
    ProductRelationship.create!(
      product_id: product.id,
      related_product_id: related_product.id,
      relationship_type: relationship_type,
      strength_score: strength_score,
      context: context
    )
    
    # Create reverse relationship
    ProductRelationship.create!(
      product_id: related_product.id,
      related_product_id: product.id,
      relationship_type: relationship_type,
      strength_score: strength_score,
      context: context
    )
  rescue => e
    puts "Error creating relationship: #{e.message}"
  end
  
  def compatible_fashion_items?(item1, item2)
    # Check if items are from same brand
    return true if item1.brand_id == item2.brand_id && item1.brand_id.present?
    
    # Check if styles are compatible
    return true if item1.style == item2.style && item1.style.present?
    
    # Check if materials are compatible
    return true if item1.material == item2.material && item1.material.present?
    
    false
  end
  
  def compatible_home_items?(item1, item2)
    # Check if items have same style
    return true if item1.style == item2.style && item1.style.present?
    
    # Check if they're from same category
    return true if item1.category_id == item2.category_id
    
    false
  end
end

