# frozen_string_literal: true

module Personalization
  class SnapshotBuilder
    def self.build(request, session)
      new(request, session).build
    end

    def initialize(request, session)
      @request = request
      @session = session
    end

    def build
      {
        page: @request.page,
        region: @request.region,
        pickup_only: @request.pickup_only,
        last_search: @session.last_search,
        views_10m: recent_product_views,
        recent_add_to_cart: has_recent_atc?,
        inactivity_bucket: determine_inactivity_bucket,
        pid: @request.pid,
        user_id: @request.user_id,
        session_id: @request.session_id,
        timestamp: Time.current.iso8601,
        # Enhanced behavioral data
        micro_events: collect_micro_events,
        meso_events: collect_meso_events,
        macro_events: collect_macro_events,
        behavioral_patterns: detect_behavioral_patterns
      }
    end

    private

    def recent_product_views
      # Get last 10 minutes of product views with metadata
      events = Event.where(
        user_id: @request.user_id,
        session_id: @request.session_id,
        event_name: "product_view",
        timestamp_utc: 10.minutes.ago..
      ).order(:timestamp_utc)
      
      events.map do |event|
        product_id = extract_product_id(event)
        product = Product.find_by(id: product_id) if product_id
        
        {
          product_id: product_id,
          product_metadata: product&.slice(:id, :name, :category_id, :brand_id, :price, :style, :color),
          timestamp: event.timestamp_utc,
          context: extract_context(event)
        }
      end.compact
    end

    def has_recent_atc?
      # Check if user added to cart in last 30 minutes
      Event.where(
        user_id: @request.user_id,
        session_id: @request.session_id,
        event_name: "add_to_cart",
        timestamp_utc: 30.minutes.ago..
      ).exists?
    end

    def determine_inactivity_bucket
      # Determine user activity level based on recent engagement
      recent_events = Event.where(
        user_id: @request.user_id,
        timestamp_utc: 1.hour.ago..
      ).count
      
      case recent_events
      when 0..2 then "dormant"
      when 3..10 then "idle"
      else "active"
      end
    end

    def collect_micro_events
      # Last 5 minutes with product metadata
      events = Event.where(
        user_id: @request.user_id,
        session_id: @request.session_id,
        timestamp_utc: 5.minutes.ago..
      ).order(:timestamp_utc)
      
      events.map do |event|
        product_id = extract_product_id(event)
        product = Product.find_by(id: product_id) if product_id
        
        {
          event_type: event.event_name,
          product: product&.slice(:id, :name, :category_id, :brand_id, :price, :style, :color),
          timestamp: event.timestamp_utc,
          weight: event_weight(event.event_name),
          context: extract_context(event)
        }
      end.compact
    end

    def collect_meso_events
      # Last hour with pattern analysis
      events = Event.where(
        user_id: @request.user_id,
        timestamp_utc: 1.hour.ago..5.minutes.ago
      ).order(:timestamp_utc)
      
      events.map do |event|
        product_id = extract_product_id(event)
        product = Product.find_by(id: product_id) if product_id
        
        {
          event_type: event.event_name,
          product: product&.slice(:id, :name, :category_id, :brand_id, :price, :style, :color),
          timestamp: event.timestamp_utc,
          weight: event_weight(event.event_name)
        }
      end.compact
    end

    def collect_macro_events
      # Last week for long-term patterns
      events = Event.where(
        user_id: @request.user_id,
        timestamp_utc: 1.week.ago..1.hour.ago
      ).order(:timestamp_utc)
      
      # Sample events to avoid overwhelming the AI
      sampled_events = events.limit(50)
      
      sampled_events.map do |event|
        product_id = extract_product_id(event)
        product = Product.find_by(id: product_id) if product_id
        
        {
          event_type: event.event_name,
          product: product&.slice(:id, :name, :category_id, :brand_id, :price, :style, :color),
          timestamp: event.timestamp_utc,
          weight: event_weight(event.event_name)
        }
      end.compact
    end

    def detect_behavioral_patterns
      # Analyze patterns in user behavior
      recent_events = Event.where(
        user_id: @request.user_id,
        timestamp_utc: 1.hour.ago..
      ).order(:timestamp_utc)
      
      {
        search_to_browse: detect_search_browse_transition(recent_events),
        category_hopping: detect_category_transitions(recent_events),
        price_exploration: detect_price_range_exploration(recent_events),
        brand_loyalty: calculate_brand_consistency(recent_events),
        engagement_velocity: calculate_engagement_velocity(recent_events)
      }
    end

    def extract_product_id(event)
      # Extract product_id from event payload
      event.payload["product_id"] || event.payload[:product_id]
    end

    def extract_context(event)
      # Extract additional context from event payload
      {
        page: event.page,
        region: event.region,
        search_term: event.payload["search_term"],
        position: event.payload["position"]
      }.compact
    end

    def event_weight(event_name)
      case event_name
      when "product_view" then 1.0
      when "add_to_cart" then 3.0
      when "purchase" then 10.0
      when "search" then 2.0
      else 1.0
      end
    end

    def detect_search_browse_transition(events)
      # Detect if user transitioned from search to browsing
      search_events = events.where(event_name: "search")
      view_events = events.where(event_name: "product_view")
      
      return false if search_events.empty? || view_events.empty?
      
      last_search = search_events.last.timestamp_utc
      first_view_after_search = view_events.where("timestamp_utc > ?", last_search).first
      
      first_view_after_search.present? && 
        (first_view_after_search.timestamp_utc - last_search) < 5.minutes
    end

    def detect_category_transitions(events)
      # Detect category hopping patterns
      product_views = events.where(event_name: "product_view")
      return [] if product_views.empty?
      
      categories = product_views.map do |event|
        product_id = extract_product_id(event)
        product = Product.find_by(id: product_id)
        product&.category_id
      end.compact.uniq
      
      categories.count > 2 # User viewed products from 3+ categories
    end

    def detect_price_range_exploration(events)
      # Detect price range exploration
      product_views = events.where(event_name: "product_view")
      return false if product_views.empty?
      
      prices = product_views.map do |event|
        product_id = extract_product_id(event)
        product = Product.find_by(id: product_id)
        product&.price
      end.compact
      
      return false if prices.empty?
      
      price_range = prices.max - prices.min
      price_range > 500 # User explored products with >500 price difference
    end

    def calculate_brand_consistency(events)
      # Calculate brand loyalty consistency
      product_views = events.where(event_name: "product_view")
      return 0.0 if product_views.empty?
      
      brands = product_views.map do |event|
        product_id = extract_product_id(event)
        product = Product.find_by(id: product_id)
        product&.brand_id
      end.compact
      
      return 0.0 if brands.empty?
      
      # Calculate brand diversity (0 = all same brand, 1 = all different brands)
      unique_brands = brands.uniq.count
      total_views = brands.count
      
      1.0 - (unique_brands.to_f / total_views)
    end

    def calculate_engagement_velocity(events)
      # Calculate actions per minute
      return 0.0 if events.blank? || events.size < 2
      first_ts = events.first&.timestamp_utc
      last_ts  = events.last&.timestamp_utc
      return 0.0 if first_ts.nil? || last_ts.nil?
      time_span = last_ts - first_ts
      return 0.0 if time_span <= 0
      
      events.count / (time_span / 1.minute)
    end
  end
end