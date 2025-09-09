# app/controllers/api/events_controller.rb
module Api
  class EventsController < Api::BaseController
    # Accept from guests too
    skip_before_action :authenticate_user!, only: [:create], raise: false

    MAX_EVENTS_PER_REQUEST = 100

    # For light schema checks (MVP)
    EVENT_RULES = {
      "product_impression" => %w[product_id feed_id],
      "product_click"      => %w[product_id feed_id],
      "feed_impression"    => %w[feed_id products],
      "feed_slice_loaded"  => %w[feed_id products],
      "search_performed"   => %w[search_term],
      "search_result_impression" => %w[search_term products],
      "search_result_click" => %w[search_term product_id position],
      "add_to_cart"        => %w[product_id quantity price_cents],
      "update_cart_qty"    => %w[product_id quantity],
      "remove_from_cart"   => %w[product_id],
      "wishlist_add"       => %w[product_id],
      "wishlist_remove"    => %w[product_id],
      # page_view/view_cart/begin_checkout/select_address/place_order_attempt can be empty
    }.freeze

    FEED_EVENTS = %w[
      product_impression product_click feed_impression feed_slice_loaded
    ].freeze

    # Strict payload whitelist
    PAYLOAD_WHITELIST = %w[
      feed_id plan_id section position product_id
      items products slice_index cursor search_term search_type
      image_name image_size image_type
      quantity price_cents category_id shop_id reason
      source_plan_id source_section source_feed_id source_page
    ].freeze

    # POST /api/events
    # Body: { events: [ {...}, {...} ], client_sent_at, app_version, sdk_version }
    def create
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      payload = params.permit!
      rows    = Array(payload[:events]).first(MAX_EVENTS_PER_REQUEST)
      return render json: { error: "Missing events[]" }, status: :bad_request if rows.blank?

      now_utc  = Time.current.utc
      accepted = []
      rejected = 0

      rows.each do |raw|
        h = raw.to_h.symbolize_keys

        # ---- global guards ---------------------------------------------------
        if h[:event_id].blank? || h[:event_name].blank? || h[:session_id].blank? || h[:page].blank? || h[:region].blank?
          rejected += 1
          next
        end

        unless Event::PAGES.include?(h[:page].to_s)
          rejected += 1
          next
        end

        name = normalize_event_name(h[:event_name].to_s)

        # timestamp: parse + clamp
        ts = parse_or_now(h[:timestamp_utc], now_utc)

        # normalize/whitelist payload
        sp = safe_payload(h[:payload])

        # server-side compat: items -> products (keeps old clients working)
        if sp["products"].blank? && sp["items"].is_a?(Array)
          sp["products"] = sp["items"].filter_map { |it| it.is_a?(Hash) ? it["id"]&.to_s : nil }
        end

        # feed events must carry a real feed_id (no "fallback")
        if FEED_EVENTS.include?(name) && (sp["feed_id"].blank? || sp["feed_id"] == "fallback")
          rejected += 1
          next
        end

        # per-event minimal schema
        if (required = EVENT_RULES[name]).present?
          missing = required.any? { |k| blankish?(sp[k]) }
          if missing
            rejected += 1
            next
          end
        end

        accepted << {
          event_id:       h[:event_id].to_s,
          user_id:        h[:user_id].presence,
          anonymous_id:   h[:anonymous_id].presence,
          session_id:     h[:session_id].to_s,
          event_name:     name,
          timestamp_utc:  ts,
          received_at:    now_utc,
          page:           h[:page].to_s,
          region:         h[:region].to_s,
          geohash6:       h[:geohash6].presence,
          schema_version: (h[:schema_version].presence || "v1"),
          payload:        sp
        }
      end

      if accepted.any?
        # Idempotent by unique index on :event_id (from your migration)
        Event.upsert_all(accepted, unique_by: :index_events_on_event_id)
      end

      # Cost tracking
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      total_cpu_seconds = end_time - start_time
      
      # Track API usage and costs
      Personalization::CostMeter.track_event_ingestion!(
        plan_id: 'events_v1',
        events_count: accepted.size
      )

      render json: { accepted: accepted.size, rejected:, received_at: now_utc.iso8601 }, status: :ok
    end

    private

    def normalize_event_name(name)
      return "feed_impression" if name == "feed_rendered" # legacy alias
      name
    end

    def blankish?(v)
      v.respond_to?(:empty?) ? v.empty? : v.nil?
    end

    def parse_or_now(ts, fallback_now)
      t = begin
        Time.iso8601(ts.to_s)
      rescue
        nil
      end
      t ||= fallback_now
      # clamp: max 10min in future
      t  = fallback_now if t > (fallback_now + 10.minutes)
      # clamp: older than 7 days → pin to 7 days ago (prevents ancient floods)
      floor = fallback_now - 7.days
      t = floor if t < floor
      t
    end

    # Keep payload small & PII-free (whitelist keys you expect)
    def safe_payload(obj)
      h = obj.is_a?(Hash) ? obj.deep_dup : {}
      # Reject any direct image URLs or unexpected keys
      h.delete("imageUrl")
      filtered = h.slice(*PAYLOAD_WHITELIST)
      filtered.compact
    end
  end
end
