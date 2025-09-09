# app/services/personalization/product_interaction_extractor.rb
# frozen_string_literal: true
#
# Service responsible for extracting and enriching product interaction data
# from user events to provide rich context for intelligent product coordination.
#
# This service:
# 1. Collects recent user interactions (last 15 minutes)
# 2. Enriches events with full product metadata
# 3. Builds interaction timelines and patterns
# 4. Provides structured data for coordination analysis
#
# Usage:
#   interactions = ProductInteractionExtractor.extract_recent_interactions(
#     user_id: 123,
#     session_id: "sess_abc123",
#     since: 15.minutes.ago
#   )
#
# Returns: Array of enriched interaction hashes with product metadata
module Personalization
  class ProductInteractionExtractor
    # Default lookback window for recent interactions
    DEFAULT_LOOKBACK = 15.minutes
    
    # Maximum number of interactions to return per type
    MAX_INTERACTIONS_PER_TYPE = {
      view: 10,
      add_to_cart: 5,
      purchase: 3,
      wishlist: 5,
      search: 3
    }
    
    class << self
      # Main method to extract recent product interactions
      # 
      # @param user_id [Integer, nil] User ID if authenticated
      # @param session_id [String] Session identifier
      # @param since [Time] Lookback time window
      # @return [Array<Hash>] Array of enriched interaction data
      def extract_recent_interactions(user_id:, session_id:, since: DEFAULT_LOOKBACK.ago)
        scope = build_event_scope(user_id: user_id, session_id: session_id, since: since)
        
        interactions = []
        
        # Extract different types of interactions
        interactions += extract_product_views(scope)
        interactions += extract_cart_interactions(scope)
        interactions += extract_purchase_interactions(scope)
        interactions += extract_wishlist_interactions(scope)
        interactions += extract_search_interactions(scope)
        
        # Sort by timestamp (most recent first)
        interactions.sort_by { |i| i[:timestamp] }.reverse
      end
      
      private
      
      # Build the base event scope for interaction extraction
      def build_event_scope(user_id:, session_id:, since:)
        scope = Event.where(session_id: session_id)
                     .where("timestamp_utc >= ?", since)
        
        # Include user events if authenticated
        if user_id.present?
          scope = scope.or(Event.where(user_id: user_id).where("timestamp_utc >= ?", since))
        end
        
        scope
      end
      
      # Extract product view interactions
      def extract_product_views(scope)
        product_views = scope.where(event_name: "product_view")
                            .order(timestamp_utc: :desc)
                            .limit(MAX_INTERACTIONS_PER_TYPE[:view])
        
        product_views.map do |event|
          product = fetch_product_with_metadata(event.payload["product_id"])
          next unless product
          
          build_interaction_data(product, event, "view")
        end.compact
      end
      
      # Extract add to cart interactions
      def extract_cart_interactions(scope)
        atc_events = scope.where(event_name: "add_to_cart")
                         .order(timestamp_utc: :desc)
                         .limit(MAX_INTERACTIONS_PER_TYPE[:add_to_cart])
        
        atc_events.map do |event|
          product = fetch_product_with_metadata(event.payload["product_id"])
          next unless product
          
          build_interaction_data(product, event, "add_to_cart")
        end.compact
      end
      
      # Extract purchase interactions
      def extract_purchase_interactions(scope)
        purchase_events = scope.where(event_name: "purchase")
                              .order(timestamp_utc: :desc)
                              .limit(MAX_INTERACTIONS_PER_TYPE[:purchase])
        
        purchase_events.map do |event|
          product = fetch_product_with_metadata(event.payload["product_id"])
          next unless product
          
          build_interaction_data(product, event, "purchase")
        end.compact
      end
      
      # Extract wishlist interactions
      def extract_wishlist_interactions(scope)
        wishlist_events = scope.where(event_name: ["wishlist_add", "wishlist_remove"])
                              .order(timestamp_utc: :desc)
                              .limit(MAX_INTERACTIONS_PER_TYPE[:wishlist])
        
        wishlist_events.map do |event|
          product = fetch_product_with_metadata(event.payload["product_id"])
          next unless product
          
          build_interaction_data(product, event, event.event_name)
        end.compact
      end
      
      # Extract search interactions
      def extract_search_interactions(scope)
        search_events = scope.where(event_name: "search_performed")
                            .order(timestamp_utc: :desc)
                            .limit(MAX_INTERACTIONS_PER_TYPE[:search])
        
        search_events.map do |event|
          search_term = event.payload["search_term"]
          next unless search_term.present?
          
          {
            interaction_type: "search",
            search_term: search_term,
            timestamp: event.timestamp_utc.iso8601,
            category: extract_search_category(search_term),
            use_case: extract_search_use_case(search_term)
          }
        end.compact
      end
      
      # Fetch product with all necessary metadata
      def fetch_product_with_metadata(product_id)
        Product.includes(:category, :brand)
               .select(:id, :name, :description, :price, :color, :size, 
                      :subcategory, :material, :style, :use_case, :specifications, 
                      :seasonality, :category_id, :brand_id)
               .find_by(id: product_id)
      end
      
      # Build standardized interaction data structure
      def build_interaction_data(product, event, interaction_type)
        {
          product_id: product.id,
          product_name: product.name,
          category: product.category&.name,
          subcategory: product.subcategory,
          brand: product.brand&.name,
          brand_category: product.brand&.category,
          brand_specialization: product.brand&.specialization,
          model: extract_model(product),
          specs: product.specifications || {},
          use_case: product.use_case,
          style: product.style,
          material: product.material,
          color: product.color,
          size: product.size,
          seasonality: product.seasonality,
          interaction_type: interaction_type,
          timestamp: event.timestamp_utc.iso8601,
          quantity: event.payload["quantity"]&.to_i || 1,
          price_cents: event.payload["price_cents"]&.to_i,
          event_id: event.event_id
        }
      end
      
      # Extract model information from product
      def extract_model(product)
        # Try to extract model from specifications first
        return product.specifications["model"] if product.specifications&.dig("model")
        
        # Extract from name using common patterns
        name = product.name.to_s
        
        # Electronics patterns
        if name.match?(/(MacBook|iPhone|iPad|Samsung|Sony|Dell|HP|Lenovo)/i)
          name.match(/(MacBook|iPhone|iPad|Samsung|Sony|Dell|HP|Lenovo)\s+[A-Za-z0-9\s]+/i)&.[](0)&.strip
        # Fashion patterns
        elsif name.match?(/(Nike|Adidas|Puma|Levi's|Calvin Klein)/i)
          name.match(/(Nike|Adidas|Puma|Levi's|Calvin Klein)\s+[A-Za-z0-9\s]+/i)&.[](0)&.strip
        # Beauty patterns
        elsif name.match?(/(The Ordinary|La Mer|Clinique|MAC)/i)
          name.match(/(The Ordinary|La Mer|Clinique|MAC)\s+[A-Za-z0-9\s]+/i)&.[](0)&.strip
        else
          # Fallback: first two words of name
          name.split.first(2).join(" ")
        end
      end
      
      # Extract category from search term
      def extract_search_category(search_term)
        term = search_term.to_s.downcase
        
        case term
        when /laptop|computer|macbook|dell|hp/i
          "Electronics"
        when /phone|iphone|samsung|android/i
          "Electronics"
        when /shirt|dress|pants|shoes|fashion/i
          "Fashion"
        when /makeup|skincare|beauty|serum|cream/i
          "Beauty"
        when /furniture|chair|table|sofa|home/i
          "Home"
        when /book|game|toy|sport/i
          "Lifestyle"
        else
          nil
        end
      end
      
      # Extract use case from search term
      def extract_search_use_case(search_term)
        term = search_term.to_s.downcase
        
        case term
        when /work|office|professional|business/i
          "professional_work"
        when /gaming|game|play/i
          "gaming"
        when /casual|everyday|daily/i
          "casual_use"
        when /formal|dress|party|event/i
          "formal_occasion"
        when /travel|trip|vacation/i
          "travel"
        when /fitness|workout|exercise/i
          "fitness"
        when /skincare|beauty|makeup/i
          "beauty_routine"
        else
          nil
        end
      end
    end
  end
end

