namespace :products do
  desc "Populate missing product metadata for intelligent shopping assistant"
  task populate_metadata: :environment do
    puts "Starting product metadata population..."
    
    total_products = Product.count
    updated_count = 0
    error_count = 0
    
    Product.find_each(batch_size: 100) do |product|
      begin
        updated = false
        
        # Extract subcategory from category name
        if product.category&.name
          case product.category.name.downcase
          when /electronics|tech/
            subcategory = extract_electronics_subcategory(product.name, product.description)
            use_case = extract_electronics_use_case(product.name, product.description)
            specs = extract_electronics_specs(product.description)
            
            if subcategory || use_case || specs.present?
              product.update!(
                subcategory: subcategory,
                use_case: use_case,
                specifications: product.specifications.merge(specs)
              )
              updated = true
            end
            
          when /beauty|cosmetics|skincare/
            subcategory = extract_beauty_subcategory(product.name)
            use_case = extract_beauty_use_case(product.name, product.description)
            style = extract_beauty_style(product.name)
            
            if subcategory || use_case || style
              product.update!(
                subcategory: subcategory,
                use_case: use_case,
                style: style
              )
              updated = true
            end
            
          when /fashion|clothing|apparel/
            subcategory = extract_fashion_subcategory(product.name)
            style = extract_fashion_style(product.name, product.description)
            material = extract_fashion_material(product.description)
            seasonality = extract_fashion_seasonality(product.name, product.description)
            
            if subcategory || style || material || seasonality
              product.update!(
                subcategory: subcategory,
                style: style,
                material: material,
                seasonality: seasonality
              )
              updated = true
            end
            
          when /home|furniture|kitchen/
            subcategory = extract_home_subcategory(product.name)
            use_case = extract_home_use_case(product.name, product.description)
            style = extract_home_style(product.description)
            
            if subcategory || use_case || style
              product.update!(
                subcategory: subcategory,
                use_case: use_case,
                style: style
              )
              updated = true
            end
          end
        end
        
        # Extract brand metadata
        if product.brand
          brand_category = extract_brand_category(product.brand.name, product.price)
          brand_specialization = extract_brand_specialization(product.brand.name, product.category&.name)
          
          if brand_category || brand_specialization
            product.brand.update!(
              category: brand_category,
              specialization: brand_specialization
            )
            updated = true
          end
        end
        
        updated_count += 1 if updated
        
        if updated_count % 100 == 0
          puts "Processed #{updated_count} products..."
        end
        
      rescue => e
        error_count += 1
        puts "Error processing product #{product.id}: #{e.message}"
      end
    end
    
    puts "\n=== Product Metadata Population Complete ==="
    puts "Total products processed: #{total_products}"
    puts "Products updated: #{updated_count}"
    puts "Errors: #{error_count}"
    puts "Success rate: #{((updated_count.to_f / total_products) * 100).round(2)}%"
  end
  
  private
  
  # Electronics extraction methods
  def extract_electronics_subcategory(name, description)
    name = name.to_s.downcase
    desc = description.to_s.downcase
    
    case
    when name.match?(/laptop|macbook|notebook|computer/i)
      "Laptops"
    when name.match?(/phone|iphone|android|mobile/i)
      "Phones"
    when name.match?(/tablet|ipad|android tablet/i)
      "Tablets"
    when name.match?(/headphone|earphone|speaker|audio/i)
      "Audio"
    when name.match?(/camera|photo|video/i)
      "Cameras"
    when name.match?(/gaming|game|console/i)
      "Gaming"
    else
      nil
    end
  end
  
  def extract_electronics_use_case(name, description)
    name = name.to_s.downcase
    desc = description.to_s.downcase
    
    case
    when name.match?(/gaming|game/i) || desc.match?(/gaming|game/i)
      "gaming"
    when name.match?(/work|office|business|professional/i) || desc.match?(/work|office|business/i)
      "professional_work"
    when name.match?(/student|study|education/i) || desc.match?(/student|study|education/i)
      "student_use"
    when name.match?(/travel|portable|mobile/i) || desc.match?(/travel|portable|mobile/i)
      "travel"
    else
      "general_use"
    end
  end
  
  def extract_electronics_specs(description)
    desc = description.to_s.downcase
    specs = {}
    
    # Extract ports
    if desc.match?(/usb-c|usb c|thunderbolt/i)
      specs["ports"] = ["USB-C", "Thunderbolt"]
    elsif desc.match?(/usb|hdmi|vga/i)
      specs["ports"] = ["USB", "HDMI"]
    end
    
    # Extract connectivity
    if desc.match?(/wifi|wireless|bluetooth/i)
      specs["connectivity"] = ["WiFi", "Bluetooth"]
    end
    
    # Extract storage
    if desc.match?(/(\d+)\s*(gb|tb)/i)
      specs["storage"] = $1 + " " + $2.upcase
    end
    
    # Extract RAM
    if desc.match?(/(\d+)\s*(gb|mb)\s*ram/i)
      specs["ram"] = $1 + " " + $2.upcase
    end
    
    specs
  end
  
  # Beauty extraction methods
  def extract_beauty_subcategory(name)
    name = name.to_s.downcase
    
    case
    when name.match?(/serum|vitamin|retinol|peptide/i)
      "Skincare"
    when name.match?(/foundation|concealer|powder|makeup/i)
      "Makeup"
    when name.match?(/shampoo|conditioner|hair|haircare/i)
      "Haircare"
    when name.match?(/perfume|fragrance|scent/i)
      "Fragrance"
    when name.match?(/brush|tool|sponge/i)
      "Tools"
    else
      "Skincare"
    end
  end
  
  def extract_beauty_use_case(name, description)
    name = name.to_s.downcase
    desc = description.to_s.downcase
    
    case
    when name.match?(/anti-aging|anti aging|wrinkle|firming/i)
      "anti_aging"
    when name.match?(/acne|blemish|spot/i)
      "acne_treatment"
    when name.match?(/brightening|glow|radiance/i)
      "brightening"
    when name.match?(/moisturizing|hydration|dry/i)
      "moisturizing"
    when name.match?(/makeup|cosmetic/i)
      "makeup_routine"
    else
      "general_skincare"
    end
  end
  
  def extract_beauty_style(name)
    name = name.to_s.downcase
    
    case
    when name.match?(/natural|organic|clean/i)
      "natural"
    when name.match?(/luxury|premium|high-end/i)
      "luxury"
    when name.match?(/drugstore|affordable|budget/i)
      "budget"
    else
      "standard"
    end
  end
  
  # Fashion extraction methods
  def extract_fashion_subcategory(name)
    name = name.to_s.downcase
    
    case
    when name.match?(/shirt|t-shirt|tshirt|blouse/i)
      "Tops"
    when name.match?(/pants|jeans|trousers|leggings/i)
      "Bottoms"
    when name.match?(/dress|gown|frock/i)
      "Dresses"
    when name.match?(/shoes|sneakers|boots|heels/i)
      "Footwear"
    when name.match?(/bag|purse|handbag|backpack/i)
      "Bags"
    when name.match?(/jewelry|necklace|ring|earring/i)
      "Accessories"
    else
      "Clothing"
    end
  end
  
  def extract_fashion_style(name, description)
    name = name.to_s.downcase
    desc = description.to_s.downcase
    
    case
    when name.match?(/casual|everyday|daily/i) || desc.match?(/casual|everyday/i)
      "casual"
    when name.match?(/formal|business|office/i) || desc.match?(/formal|business/i)
      "formal"
    when name.match?(/vintage|retro|classic/i) || desc.match?(/vintage|retro/i)
      "vintage"
    when name.match?(/sport|athletic|fitness/i) || desc.match?(/sport|athletic/i)
      "athletic"
    else
      "standard"
    end
  end
  
  def extract_fashion_material(description)
    desc = description.to_s.downcase
    
    case
    when desc.match?(/cotton/i)
      "cotton"
    when desc.match?(/polyester/i)
      "polyester"
    when desc.match?(/leather/i)
      "leather"
    when desc.match?(/denim/i)
      "denim"
    when desc.match?(/silk/i)
      "silk"
    when desc.match?(/wool/i)
      "wool"
    else
      nil
    end
  end
  
  def extract_fashion_seasonality(name, description)
    name = name.to_s.downcase
    desc = description.to_s.downcase
    
    case
    when name.match?(/summer|spring/i) || desc.match?(/summer|spring/i)
      "summer"
    when name.match?(/winter|fall|autumn/i) || desc.match?(/winter|fall|autumn/i)
      "winter"
    when name.match?(/all-season|all season/i) || desc.match?(/all-season|all season/i)
      "all_season"
    else
      nil
    end
  end
  
  # Home extraction methods
  def extract_home_subcategory(name)
    name = name.to_s.downcase
    
    case
    when name.match?(/chair|sofa|couch|table|desk/i)
      "Furniture"
    when name.match?(/lamp|light|lighting/i)
      "Lighting"
    when name.match?(/kitchen|cook|bake/i)
      "Kitchen"
    when name.match?(/bed|bedroom|sleep/i)
      "Bedroom"
    when name.match?(/bath|bathroom/i)
      "Bathroom"
    else
      "Furniture"
    end
  end
  
  def extract_home_use_case(name, description)
    name = name.to_s.downcase
    desc = description.to_s.downcase
    
    case
    when name.match?(/office|work|study/i) || desc.match?(/office|work|study/i)
      "home_office"
    when name.match?(/kitchen|cook|bake/i) || desc.match?(/kitchen|cook|bake/i)
      "kitchen_use"
    when name.match?(/bedroom|sleep|rest/i) || desc.match?(/bedroom|sleep|rest/i)
      "bedroom_use"
    when name.match?(/living|entertainment/i) || desc.match?(/living|entertainment/i)
      "living_space"
    else
      "general_home"
    end
  end
  
  def extract_home_style(description)
    desc = description.to_s.downcase
    
    case
    when desc.match?(/modern|contemporary/i)
      "modern"
    when desc.match?(/traditional|classic/i)
      "traditional"
    when desc.match?(/rustic|country/i)
      "rustic"
    when desc.match?(/minimal|minimalist/i)
      "minimalist"
    else
      nil
    end
  end
  
  # Brand extraction methods
  def extract_brand_category(brand_name, price)
    brand = brand_name.to_s.downcase
    price_val = price.to_f
    
    case
    when brand.match?(/apple|sony|samsung|dell|hp|lenovo/i) || price_val > 1000
      "premium"
    when brand.match?(/nike|adidas|calvin klein|levi/i) || price_val > 100
      "mid_range"
    when price_val < 50
      "budget"
    else
      "standard"
    end
  end
  
  def extract_brand_specialization(brand_name, category_name)
    brand = brand_name.to_s.downcase
    category = category_name.to_s.downcase
    
    case
    when brand.match?(/apple|sony|samsung|dell|hp|lenovo/i) || category&.match?(/electronics|tech/i)
      "tech"
    when brand.match?(/nike|adidas|levi|calvin klein/i) || category&.match?(/fashion|clothing/i)
      "fashion"
    when brand.match?(/the ordinary|la mer|clinique|mac/i) || category&.match?(/beauty|cosmetics/i)
      "beauty"
    when brand.match?(/ikea|wayfair|west elm/i) || category&.match?(/home|furniture/i)
      "home"
    else
      "general"
    end
  end
end

