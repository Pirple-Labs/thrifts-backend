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
        pid: @request.product_id,
        user_id: @request.user_id,
        session_id: @request.session_id
      }
    end

    private

    def recent_product_views
      # Get last 10 minutes of product views
      # Simplified for demo - in real implementation would extract product_id from payload
      []
    end

    def has_recent_atc?
      # Check if user added to cart in last 30 minutes
      Event.where(event_name: "add_to_cart")
           .where("timestamp_utc >= ?", 30.minutes.ago)
           .exists?
    end

    def determine_inactivity_bucket
      # Determine user activity level based on recent engagement
      recent_events = Event.where("timestamp_utc >= ?", 1.hour.ago).count
      
      case recent_events
      when 0..2 then "dormant"
      when 3..10 then "idle"
      else "active"
      end
    end
  end
end