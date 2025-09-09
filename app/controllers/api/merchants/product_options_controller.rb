module Api
  module Merchants
    class ProductOptionsController < Api::BaseController
      
      # GET /api/merchants/product_options/categories/:category_id
      def category_options
        category = Category.find_by(id: params[:category_id])
        return render json: { error: "Category not found" }, status: :not_found unless category
        
        options = case category.name.downcase
        when /electronics|tech/
          electronics_options
        when /beauty|skincare|makeup/
          beauty_options
        when /fashion|clothing|apparel/
          fashion_options
        when /home|furniture|decor/
          home_options
        else
          general_options
        end
        
        render json: {
          success: true,
          category_name: category.name,
          options: options
        }
      end
      
      # GET /api/merchants/product_options/brands
      def brands
        brands = Brand.order(:name).map do |brand|
          {
            id: brand.id,
            name: brand.name,
            category: brand.category,
            specialization: brand.specialization
          }
        end
        
        render json: {
          success: true,
          brands: brands
        }
      end
      
      # GET /api/merchants/product_options/specification_fields/:category_id
      def specification_fields
        category = Category.find_by(id: params[:category_id])
        return render json: { error: "Category not found" }, status: :not_found unless category
        
        fields = case category.name.downcase
        when /electronics|tech/
          electronics_spec_fields
        when /beauty|skincare|makeup/
          beauty_spec_fields
        when /fashion|clothing|apparel/
          fashion_spec_fields
        when /home|furniture|decor/
          home_spec_fields
        else
          []
        end
        
        render json: {
          success: true,
          category_name: category.name,
          fields: fields
        }
      end
      
      private
      
      def electronics_options
        {
          subcategory: [
            { value: "Laptops", label: "Laptops" },
            { value: "Phones", label: "Phones" },
            { value: "Tablets", label: "Tablets" },
            { value: "Audio", label: "Audio" },
            { value: "Gaming", label: "Gaming" },
            { value: "Cameras", label: "Cameras" },
            { value: "Peripherals", label: "Peripherals" },
            { value: "Smart Home", label: "Smart Home" }
          ],
          material: [
            { value: "aluminum", label: "Aluminum" },
            { value: "plastic", label: "Plastic" },
            { value: "glass", label: "Glass" },
            { value: "carbon_fiber", label: "Carbon Fiber" },
            { value: "steel", label: "Steel" },
            { value: "titanium", label: "Titanium" }
          ],
          style: [
            { value: "premium", label: "Premium" },
            { value: "minimalist", label: "Minimalist" },
            { value: "gaming", label: "Gaming" },
            { value: "professional", label: "Professional" },
            { value: "modern", label: "Modern" },
            { value: "retro", label: "Retro" }
          ],
          use_case: [
            { value: "professional_work", label: "Professional Work" },
            { value: "gaming", label: "Gaming" },
            { value: "student_use", label: "Student Use" },
            { value: "creative_work", label: "Creative Work" },
            { value: "travel", label: "Travel" },
            { value: "entertainment", label: "Entertainment" },
            { value: "fitness", label: "Fitness & Health" }
          ]
        }
      end
      
      def beauty_options
        {
          subcategory: [
            { value: "Skincare", label: "Skincare" },
            { value: "Makeup", label: "Makeup" },
            { value: "Haircare", label: "Haircare" },
            { value: "Fragrance", label: "Fragrance" },
            { value: "Tools", label: "Tools & Brushes" },
            { value: "Bath & Body", label: "Bath & Body" },
            { value: "Nail Care", label: "Nail Care" }
          ],
          material: [
            { value: "natural", label: "Natural" },
            { value: "organic", label: "Organic" },
            { value: "synthetic", label: "Synthetic" },
            { value: "mineral", label: "Mineral" },
            { value: "vegan", label: "Vegan" },
            { value: "cruelty_free", label: "Cruelty-Free" }
          ],
          style: [
            { value: "natural", label: "Natural" },
            { value: "luxury", label: "Luxury" },
            { value: "budget", label: "Budget" },
            { value: "clean_beauty", label: "Clean Beauty" },
            { value: "k_beauty", label: "K-Beauty" },
            { value: "j_beauty", label: "J-Beauty" }
          ],
          use_case: [
            { value: "anti_aging", label: "Anti-Aging" },
            { value: "acne_treatment", label: "Acne Treatment" },
            { value: "brightening", label: "Brightening" },
            { value: "moisturizing", label: "Moisturizing" },
            { value: "makeup_routine", label: "Makeup Routine" },
            { value: "skincare_routine", label: "Skincare Routine" },
            { value: "hair_styling", label: "Hair Styling" }
          ]
        }
      end
      
      def fashion_options
        {
          subcategory: [
            { value: "Tops", label: "Tops" },
            { value: "Bottoms", label: "Bottoms" },
            { value: "Dresses", label: "Dresses" },
            { value: "Footwear", label: "Footwear" },
            { value: "Bags", label: "Bags" },
            { value: "Accessories", label: "Accessories" },
            { value: "Outerwear", label: "Outerwear" },
            { value: "Activewear", label: "Activewear" }
          ],
          material: [
            { value: "cotton", label: "Cotton" },
            { value: "polyester", label: "Polyester" },
            { value: "leather", label: "Leather" },
            { value: "denim", label: "Denim" },
            { value: "silk", label: "Silk" },
            { value: "wool", label: "Wool" },
            { value: "linen", label: "Linen" },
            { value: "suede", label: "Suede" }
          ],
          style: [
            { value: "casual", label: "Casual" },
            { value: "formal", label: "Formal" },
            { value: "vintage", label: "Vintage" },
            { value: "athletic", label: "Athletic" },
            { value: "streetwear", label: "Streetwear" },
            { value: "bohemian", label: "Bohemian" },
            { value: "minimalist", label: "Minimalist" }
          ],
          use_case: [
            { value: "daily_wear", label: "Daily Wear" },
            { value: "formal_occasion", label: "Formal Occasion" },
            { value: "work_attire", label: "Work Attire" },
            { value: "sport_fitness", label: "Sport & Fitness" },
            { value: "party_event", label: "Party & Events" },
            { value: "travel", label: "Travel" },
            { value: "loungewear", label: "Loungewear" }
          ]
        }
      end
      
      def home_options
        {
          subcategory: [
            { value: "Furniture", label: "Furniture" },
            { value: "Decor", label: "Decor" },
            { value: "Kitchen", label: "Kitchen" },
            { value: "Bathroom", label: "Bathroom" },
            { value: "Bedding", label: "Bedding" },
            { value: "Lighting", label: "Lighting" },
            { value: "Storage", label: "Storage" },
            { value: "Garden", label: "Garden & Outdoor" }
          ],
          material: [
            { value: "wood", label: "Wood" },
            { value: "metal", label: "Metal" },
            { value: "glass", label: "Glass" },
            { value: "ceramic", label: "Ceramic" },
            { value: "fabric", label: "Fabric" },
            { value: "plastic", label: "Plastic" },
            { value: "stone", label: "Stone" }
          ],
          style: [
            { value: "modern", label: "Modern" },
            { value: "traditional", label: "Traditional" },
            { value: "minimalist", label: "Minimalist" },
            { value: "bohemian", label: "Bohemian" },
            { value: "industrial", label: "Industrial" },
            { value: "scandinavian", label: "Scandinavian" },
            { value: "vintage", label: "Vintage" }
          ],
          use_case: [
            { value: "living_room", label: "Living Room" },
            { value: "bedroom", label: "Bedroom" },
            { value: "kitchen", label: "Kitchen" },
            { value: "bathroom", label: "Bathroom" },
            { value: "home_office", label: "Home Office" },
            { value: "outdoor", label: "Outdoor" },
            { value: "storage", label: "Storage & Organization" }
          ]
        }
      end
      
      def general_options
        {
          subcategory: [],
          material: [],
          style: [],
          use_case: []
        }
      end
      
      def electronics_spec_fields
        [
          {
            name: "ports",
            label: "Ports",
            type: "multi_select",
            options: ["USB-C", "Thunderbolt", "USB-A", "HDMI", "VGA", "Ethernet", "Audio Jack", "SD Card"],
            placeholder: "Select available ports..."
          },
          {
            name: "connectivity",
            label: "Connectivity",
            type: "multi_select",
            options: ["WiFi 6", "Bluetooth 5.0", "5G", "4G LTE", "NFC", "GPS", "Ethernet"],
            placeholder: "Select connectivity options..."
          },
          {
            name: "storage",
            label: "Storage",
            type: "text",
            placeholder: "e.g., 512GB SSD, 1TB HDD"
          },
          {
            name: "ram",
            label: "RAM",
            type: "text",
            placeholder: "e.g., 16GB, 32GB"
          },
          {
            name: "processor",
            label: "Processor",
            type: "text",
            placeholder: "e.g., M3 Pro, Intel i7, AMD Ryzen 7"
          },
          {
            name: "display",
            label: "Display",
            type: "text",
            placeholder: "e.g., 14-inch Retina, 4K OLED"
          },
          {
            name: "battery",
            label: "Battery Life",
            type: "text",
            placeholder: "e.g., Up to 10 hours, 5000mAh"
          }
        ]
      end
      
      def beauty_spec_fields
        [
          {
            name: "skin_type",
            label: "Skin Type",
            type: "multi_select",
            options: ["Oily", "Dry", "Combination", "Sensitive", "Normal", "Mature", "Acne-Prone"],
            placeholder: "Select suitable skin types..."
          },
          {
            name: "ingredients",
            label: "Key Ingredients",
            type: "multi_select",
            options: ["Hyaluronic Acid", "Retinol", "Vitamin C", "Niacinamide", "Peptides", "Ceramides", "Alpha Hydroxy Acids"],
            placeholder: "Select key ingredients..."
          },
          {
            name: "application",
            label: "Application",
            type: "select",
            options: ["Morning", "Evening", "Both", "As Needed", "Weekly", "Monthly"],
            placeholder: "When to apply..."
          },
          {
            name: "texture",
            label: "Texture",
            type: "select",
            options: ["Gel", "Cream", "Serum", "Oil", "Lotion", "Mask", "Toner"],
            placeholder: "Product texture..."
          }
        ]
      end
      
      def fashion_spec_fields
        [
          {
            name: "fit",
            label: "Fit",
            type: "select",
            options: ["Slim", "Regular", "Loose", "Oversized", "Custom", "Relaxed", "Tapered"],
            placeholder: "How does it fit?"
          },
          {
            name: "care_instructions",
            label: "Care Instructions",
            type: "multi_select",
            options: ["Machine Wash", "Hand Wash", "Dry Clean", "Air Dry", "Iron Low", "Iron Medium", "Iron High", "Bleach Safe"],
            placeholder: "Select care instructions..."
          },
          {
            name: "sizes_available",
            label: "Available Sizes",
            type: "multi_select",
            options: ["XS", "S", "M", "L", "XL", "XXL", "Custom", "Petite", "Plus Size"],
            placeholder: "Select available sizes..."
          },
          {
            name: "closure",
            label: "Closure Type",
            type: "select",
            options: ["Zipper", "Buttons", "Hook & Eye", "Elastic", "Drawstring", "Velcro", "Snap"],
            placeholder: "How does it close?"
          }
        ]
      end
      
      def home_spec_fields
        [
          {
            name: "dimensions",
            label: "Dimensions",
            type: "text",
            placeholder: "e.g., 24\"W x 18\"D x 36\"H"
          },
          {
            name: "weight",
            label: "Weight",
            type: "text",
            placeholder: "e.g., 15 lbs, 7 kg"
          },
          {
            name: "assembly",
            label: "Assembly Required",
            type: "select",
            options: ["No Assembly", "Some Assembly", "Full Assembly", "Professional Installation"],
            placeholder: "Assembly requirements..."
          },
          {
            name: "warranty",
            label: "Warranty",
            type: "text",
            placeholder: "e.g., 1 year limited, lifetime"
          }
        ]
      end
    end
  end
end

