# app/services/personalization/coordination_context_analyzer.rb
# frozen_string_literal: true
#
# Service responsible for analyzing product interactions to understand
# user coordination needs and generate intelligent product suggestions.
module Personalization
  class CoordinationContextAnalyzer
    # Weight multipliers for different interaction types
    INTERACTION_WEIGHTS = {
      "purchase" => 3.0,      # Highest weight - they bought it
      "add_to_cart" => 2.0,   # High weight - they want it
      "view" => 1.0,          # Base weight - they're interested
      "wishlist_add" => 1.5,  # Medium weight - they like it
      "search" => 0.8         # Lower weight - they're exploring
    }.freeze
    
    class << self
      # Main method to analyze coordination context from interactions
      def analyze_context(interactions)
        return empty_context if interactions.empty?
        
        # Extract primary categories and use cases
        categories = extract_primary_categories(interactions)
        use_cases = extract_primary_use_cases(interactions)
        
        # Identify compatibility needs and completion items
        compatibility_needs = identify_compatibility_needs(interactions)
        completion_items = identify_completion_items(interactions, use_cases)
        
        # Generate coordination strategy
        coordination_strategy = generate_coordination_strategy(interactions, categories, use_cases)
        
        {
          primary_categories: categories,
          use_cases: use_cases,
          compatibility_needs: compatibility_needs,
          completion_items: completion_items,
          coordination_strategy: coordination_strategy,
          interaction_summary: build_interaction_summary(interactions)
        }
      end
      
      private
      
      # Extract primary categories from interactions
      def extract_primary_categories(interactions)
        category_scores = Hash.new(0.0)
        
        interactions.each do |interaction|
          next unless interaction[:category].present?
          
          weight = INTERACTION_WEIGHTS[interaction[:interaction_type]] || 1.0
          category_scores[interaction[:category]] += weight
        end
        
        # Return top 3 categories by score
        category_scores.sort_by { |_, score| -score }
                      .first(3)
                      .map { |category, _| category }
      end
      
      # Extract primary use cases from interactions
      def extract_primary_use_cases(interactions)
        use_case_scores = Hash.new(0.0)
        
        interactions.each do |interaction|
          next unless interaction[:use_case].present?
          
          weight = INTERACTION_WEIGHTS[interaction[:interaction_type]] || 1.0
          use_case_scores[interaction[:use_case]] += weight
        end
        
        # Return top 3 use cases by score
        use_case_scores.sort_by { |_, score| -score }
                       .first(3)
                       .map { |use_case, _| use_case }
      end
      
      # Identify compatibility needs based on interactions
      def identify_compatibility_needs(interactions)
        needs = []
        
        interactions.each do |interaction|
          next unless interaction[:category].present?
          
          case interaction[:category]
          when "Electronics"
            needs += extract_electronics_needs(interaction)
          when "Beauty"
            needs += extract_beauty_needs(interaction)
          when "Fashion"
            needs += extract_fashion_needs(interaction)
          when "Home"
            needs += extract_home_needs(interaction)
          end
        end
        
        needs.uniq
      end
      
      # Extract electronics compatibility needs
      def extract_electronics_needs(interaction)
        needs = []
        
        case interaction[:subcategory]
        when "Laptops"
          needs << "USB-C accessories" if has_usb_c_ports?(interaction)
          needs << "wireless peripherals" if has_bluetooth?(interaction)
          needs << "docking station" if interaction[:use_case] == "professional_work"
          needs << "gaming accessories" if interaction[:use_case] == "gaming"
        when "Phones"
          needs += ["phone cases", "screen protectors", "charging cables"]
          needs << "wireless charging" if has_wireless_charging?(interaction)
        when "Audio"
          needs += ["cables", "adapters", "storage solutions"]
        end
        
        needs
      end
      
      # Extract beauty compatibility needs
      def extract_beauty_needs(interaction)
        needs = []
        
        case interaction[:subcategory]
        when "Skincare"
          needs += ["cleansers", "moisturizers", "sunscreen"]
          needs << "skincare tools" if interaction[:use_case] == "beauty_routine"
        when "Makeup"
          needs += ["makeup brushes", "makeup removers", "primers"]
          needs << "makeup storage" if interaction[:use_case] == "beauty_routine"
        when "Haircare"
          needs += ["shampoo", "conditioner", "styling products"]
        end
        
        needs
      end
      
      # Extract fashion compatibility needs
      def extract_fashion_needs(interaction)
        needs = []
        
        case interaction[:subcategory]
        when "Clothing"
          needs += ["matching accessories", "shoes", "bags"]
          needs << "formal accessories" if interaction[:use_case] == "formal_occasion"
        when "Shoes"
          needs += ["socks", "insoles", "care products"]
        when "Accessories"
          needs += ["jewelry", "belts", "scarves"]
        end
        
        needs
      end
      
      # Extract home compatibility needs
      def extract_home_needs(interaction)
        needs = []
        
        case interaction[:subcategory]
        when "Furniture"
          needs += ["decor", "lighting", "storage solutions"]
        when "Kitchen"
          needs += ["appliances", "utensils", "storage"]
        when "Bedroom"
          needs += ["bedding", "lighting", "storage"]
        end
        
        needs
      end
      
      # Identify completion items based on use cases
      def identify_completion_items(interactions, use_cases)
        items = []
        
        use_cases.each do |use_case|
          case use_case
          when "professional_work"
            items += ["mouse", "keyboard", "monitor", "laptop stand", "docking station"]
          when "gaming"
            items += ["gaming mouse", "gaming keyboard", "headset", "mousepad"]
          when "skincare_routine"
            items += ["cleanser", "moisturizer", "sunscreen", "face wash"]
          when "makeup_routine"
            items += ["foundation", "concealer", "powder", "brushes"]
          when "casual_wear"
            items += ["accessories", "outerwear", "underwear"]
          end
        end
        
        # Remove items user already has
        existing_items = extract_existing_items(interactions)
        items.reject { |item| existing_items.any? { |existing| existing.downcase.include?(item.downcase) } }
      end
      
      # Extract existing items from interactions
      def extract_existing_items(interactions)
        interactions.map do |interaction|
          [
            interaction[:model],
            interaction[:product_name],
            interaction[:subcategory]
          ].compact
        end.flatten.uniq
      end
      
      # Generate coordination strategy
      def generate_coordination_strategy(interactions, categories, use_cases)
        {
          primary_focus: determine_primary_focus(interactions),
          coordination_approach: determine_coordination_approach(categories, use_cases),
          priority_items: determine_priority_items(interactions, use_cases),
          cross_category_opportunities: identify_cross_category_opportunities(categories)
        }
      end
      
      # Determine primary focus area
      def determine_primary_focus(interactions)
        return "exploration" if interactions.empty?
        
        if interactions.any? { |i| i[:interaction_type] == "purchase" }
          "completion"  # They're buying, help them complete
        elsif interactions.any? { |i| i[:interaction_type] == "add_to_cart" }
          "enhancement"  # They're building, help them enhance
        elsif interactions.any? { |i| i[:interaction_type] == "view" }
          "discovery"    # They're browsing, help them discover
        else
          "exploration"  # Default to exploration
        end
      end
      
      # Determine coordination approach
      def determine_coordination_approach(categories, use_cases)
        if categories.length > 1
          "cross_category"  # Multiple categories, focus on coordination
        elsif use_cases.length > 1
          "use_case_completion"  # Multiple use cases, focus on completion
        else
          "category_deep_dive"  # Single category, focus on depth
        end
      end
      
      # Determine priority items
      def determine_priority_items(interactions, use_cases)
        priorities = []
        
        use_cases.each do |use_case|
          case use_case
          when "professional_work"
            priorities += ["mouse", "keyboard", "monitor"].map { |item| { item: item, priority: "high", reason: "essential_for_work" } }
          when "skincare_routine"
            priorities += ["cleanser", "moisturizer", "sunscreen"].map { |item| { item: item, priority: "high", reason: "essential_for_skincare" } }
          end
        end
        
        priorities
      end
      
      # Identify cross-category opportunities
      def identify_cross_category_opportunities(categories)
        opportunities = []
        
        categories.combination(2).each do |cat1, cat2|
          case [cat1, cat2]
          when ["Electronics", "Fashion"]
            opportunities << "tech_accessories_for_style"
          when ["Beauty", "Fashion"]
            opportunities << "beauty_complements_for_outfits"
          when ["Home", "Electronics"]
            opportunities << "smart_home_integration"
          end
        end
        
        opportunities
      end
      
      # Build interaction summary
      def build_interaction_summary(interactions)
        {
          total_interactions: interactions.length,
          interaction_types: interactions.group_by { |i| i[:interaction_type] }.transform_values(&:length),
          time_span: calculate_time_span(interactions),
          engagement_level: calculate_engagement_level(interactions)
        }
      end
      
      # Calculate time span of interactions
      def calculate_time_span(interactions)
        return "unknown" if interactions.empty?
        
        timestamps = interactions.map { |i| Time.parse(i[:timestamp]) rescue nil }.compact
        return "unknown" if timestamps.empty?
        
        duration = timestamps.max - timestamps.min
        case duration
        when 0..5.minutes
          "focused_session"
        when 5.minutes..30.minutes
          "extended_session"
        else
          "spread_session"
        end
      end
      
      # Calculate engagement level
      def calculate_engagement_level(interactions)
        return "low" if interactions.empty?
        
        score = interactions.sum { |i| INTERACTION_WEIGHTS[i[:interaction_type]] || 1.0 }
        
        case score
        when 0..5
          "low"
        when 5..15
          "medium"
        else
          "high"
        end
      end
      
      # Helper methods for compatibility detection
      def has_usb_c_ports?(interaction)
        interaction[:specs]&.dig("ports")&.any? { |port| port.to_s.downcase.include?("usb-c") } ||
        interaction[:product_name]&.downcase&.include?("usb-c")
      end
      
      def has_bluetooth?(interaction)
        interaction[:specs]&.dig("connectivity")&.any? { |conn| conn.to_s.downcase.include?("bluetooth") } ||
        interaction[:product_name]&.downcase&.include?("bluetooth")
      end
      
      def has_wireless_charging?(interaction)
        interaction[:specs]&.dig("charging")&.any? { |charge| charge.to_s.downcase.include?("wireless") } ||
        interaction[:product_name]&.downcase&.include?("wireless")
      end
      
      # Return empty context when no interactions
      def empty_context
        {
          primary_categories: [],
          use_cases: [],
          compatibility_needs: [],
          completion_items: [],
          coordination_strategy: {
            primary_focus: "exploration",
            coordination_approach: "discovery",
            priority_items: [],
            cross_category_opportunities: []
          },
          interaction_summary: {
            total_interactions: 0,
            interaction_types: {},
            time_span: "unknown",
            engagement_level: "low"
          }
        }
      end
    end
  end
end
