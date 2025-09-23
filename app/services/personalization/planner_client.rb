# frozen_string_literal: true

module Personalization
  class PlannerClient
    class Error < StandardError; end
    
    ENDPOINT = ENV.fetch("PERSONALIZATION_OPERATOR_URL") { "https://operator.internal" } + "/operator/query-pack"
    TIMEOUT_MS = Integer(ENV.fetch("OPERATOR_TIMEOUT_MS", 30000)) # 30 seconds default
    
    def self.fetch_plan(page:, snapshot:, profile:, session_embed_summary:, constraints:)
      payload = build_payload(page, snapshot, profile, session_embed_summary, constraints)
      headers = build_headers
      
      http = HTTP
        .timeout(TIMEOUT_MS / 1000.0)
        .headers(headers)
      
      resp = nil
      begin
        resp = http.post(ENDPOINT, json: payload)
      rescue HTTP::TimeoutError, HTTP::ConnectionError => e
        Rails.logger.warn("PlannerClient timeout/connection error: #{e.message}")
        return control_plan(page)
      end
      
      if resp.status.success?
        json = resp.parse
        return validate_and_process_ai_response(json, page)
      end
      
      # Optional single retry on 5xx if time allows
      if resp.status.server_error?
        begin
          resp = http.post(ENDPOINT, json: payload)
          return resp.parse if resp.status.success?
        rescue StandardError => e
          Rails.logger.warn("PlannerClient retry failed: #{e.message}")
          # fall through
        end
      end
      
      # Handle different error cases
      handle_error_response(resp, page)
    end
    
    private
    
    def self.build_payload(page, snapshot, profile, session_embed_summary, constraints)
      {
        page: page,
        snapshot: snapshot,
        profile: profile,
        session_embed_summary: session_embed_summary,
        constraints: constraints,
        # Enhanced context for AI
        user_context: {
          user_id: snapshot[:user_id],
          session_id: snapshot[:session_id],
          page: snapshot[:page],
          region: snapshot[:region],
          timestamp: snapshot[:timestamp],
          behavioral_patterns: snapshot[:behavioral_patterns],
          micro_events: snapshot[:micro_events],
          meso_events: snapshot[:meso_events],
          macro_events: snapshot[:macro_events]
        },
        # AI instruction context
        ai_instructions: {
          task: "generate_personalized_sections",
          requirements: {
            dynamic_sections: true,
            personalized_titles: true,
            search_strategies: true,
            max_sections: 5,
            section_types: ["trending", "similar", "complementary", "discovery", "completion"]
          }
        },
        snapshot: normalize_snapshot(snapshot),
        profile: profile,
        constraints: constraints,
        session_embed_summary: normalize_session_embed_summary(session_embed_summary),
        plan_cache_hint: {
          profile_hash: Personalization::ProfileHasher.hash(snapshot, profile),
          ttl_seconds: 172800
        }
      }
    end
    
    def self.build_headers
      {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        # For STS (Same Trust Store) communications, skip JWT authentication
        # "Authorization" => "Bearer #{generate_jwt_token}",
        "X-Request-Id" => Current.request_id || SecureRandom.uuid,
        "X-Plan-DSL-Version" => "1.0-mvp"
      }
    end
    
    def self.normalize_snapshot(snapshot)
      {
        region: snapshot[:region] || "ke",
        pickup_only: snapshot[:pickup_only] || false,
        last_search: snapshot[:last_search] || "",
        views_10m: snapshot[:views_10m].is_a?(Array) ? snapshot[:views_10m].count : (snapshot[:views_10m] || 0),
        recent_add_to_cart: snapshot[:recent_add_to_cart] || false,
        inactivity_bucket: normalize_inactivity_bucket(snapshot[:inactivity_bucket]),
        pid: snapshot[:pid]
      }
    end
    
    def self.normalize_session_embed_summary(session_embed_summary)
      {
        topics: session_embed_summary[:topic_slate] || ["general"],
        centroid_bucket: session_embed_summary[:centroid_hash] || "v3-bkt-00"
      }
    end
    
    def self.normalize_inactivity_bucket(bucket)
      case bucket
      when "dormant" then "gt_30d"
      when "idle" then "7_30d"
      when "active" then "0_10m"
      else "10_60m"
      end
    end
    
    def self.generate_jwt_token
      # Generate JWT token for Operator authentication
      payload = {
        iss: "rails.personalization",
        aud: "operator.personalization",
        exp: 5.minutes.from_now.to_i,
        iat: Time.current.to_i
      }
      
      JWT.encode(payload, jwt_secret, 'HS256')
    end
    
    def self.jwt_secret
      ENV['PERSONALIZATION_JWT_SECRET'] || Rails.application.secret_key_base
    end
    
    def self.handle_error_response(resp, page)
      case resp.status
      when 400
        Rails.logger.error("PlannerClient schema validation error: #{resp.body}")
        control_plan(page)
      when 401, 403
        Rails.logger.error("PlannerClient authentication error: #{resp.status}")
        # Alert operations team
        alert_operations("Operator authentication failed")
        control_plan(page)
      when 408, 504
        Rails.logger.warn("PlannerClient timeout: #{resp.status}")
        control_plan(page)
      else
        Rails.logger.error("PlannerClient server error: #{resp.status} - #{resp.body}")
        control_plan(page)
      end
    end
    
    def self.alert_operations(message)
      # Send alert to operations team
      Rails.logger.error("OPERATIONS_ALERT: #{message}")
      # Could integrate with PagerDuty, Slack, etc.
    end
    
    def self.validate_and_process_ai_response(json, page)
      # Validate AI response structure
      unless json.is_a?(Hash) && json["sections"].is_a?(Array)
        Rails.logger.warn("Invalid AI response structure: #{json}")
        return control_plan(page)
      end

      # Process and validate each section
      processed_sections = json["sections"].map do |section|
        validate_section(section)
      end.compact

      # Ensure we have at least one valid section
      if processed_sections.empty?
        Rails.logger.warn("No valid sections in AI response")
        return control_plan(page)
      end

      # Add metadata
      {
        sections: processed_sections,
        metadata: {
          ai_generated: true,
          timestamp: Time.current.iso8601,
          page: page,
          section_count: processed_sections.count
        }
      }
    end

    def self.validate_section(section)
      # Validate required fields
      required_fields = %w[id title type]
      missing_fields = required_fields - section.keys
      
      if missing_fields.any?
        Rails.logger.warn("Section missing required fields #{missing_fields}: #{section}")
        return nil
      end

      # Validate section type
      valid_types = %w[trending similar complementary discovery completion personalized]
      unless valid_types.include?(section["type"])
        Rails.logger.warn("Invalid section type '#{section['type']}': #{section}")
        return nil
      end

      # Ensure filters and knobs are hashes
      section["filters"] ||= {}
      section["knobs"] ||= {}

      # Add default knobs if missing
      section["knobs"]["limit"] ||= 20
      section["knobs"]["algorithm"] ||= "default"

      section
    end

    def self.control_plan(page)
      ControlPlan.for(page)
    end
  end
  
  # Control plan generator following MVP contract
  class ControlPlan
    def self.for(page)
      case page
      when "home"
        {
          plan_id: "control_home_#{Time.current.strftime('%Y%m%d_%H%M%S')}",
          source: "control",
          ttl_seconds: 172800,
          page: "home",
          sections: [
            {
              id: "session_picks",
              count: 12,
              filters: {
                categories: [],
                price_band: "mid",
                fresh_days: 0,
                region: "ke",
                pickup_only: false
              },
              reason: "Based on your recent activity"
            },
            {
              id: "lookalikes",
              count: 12,
              filters: {
                categories: [],
                price_band: "mid",
                fresh_days: 30,
                region: "ke",
                pickup_only: false
              },
              reason: "Similar to what you've been browsing"
            },
            {
              id: "trending_near_you",
              count: 12,
              filters: {
                categories: [],
                price_band: "mid",
                region: "ke",
                pickup_only: false
              },
              reason: "Trending in your area"
            }
          ],
          copy_style: { tone: "friendly", max_reason_len: 80 },
          version: "1.0-mvp"
        }
      when "search"
        {
          plan_id: "control_search_#{Time.current.strftime('%Y%m%d_%H%M%S')}",
          source: "control",
          ttl_seconds: 172800,
          page: "search",
          sections: [
            {
              id: "search_results",
              count: 24,
              filters: {
                categories: [],
                price_band: "mid",
                fresh_days: 0,
                region: "ke",
                pickup_only: false
              },
              reason: "Search results"
            },
            {
              id: "lookalikes",
              count: 12,
              filters: {
                categories: [],
                price_band: "mid",
                fresh_days: 30,
                region: "ke",
                pickup_only: false
              },
              reason: "Similar items"
            }
          ],
          copy_style: { tone: "friendly", max_reason_len: 80 },
          version: "1.0-mvp"
        }
      when "pdp"
        {
          plan_id: "control_pdp_#{Time.current.strftime('%Y%m%d_%H%M%S')}",
          source: "control",
          ttl_seconds: 172800,
          page: "pdp",
          sections: [
            {
              id: "similar_items",
              count: 12,
              filters: {
                categories: [],
                price_band: "mid",
                fresh_days: 0,
                region: "ke",
                pickup_only: false
              },
              reason: "Similar products"
            },
            {
              id: "complete_the_look",
              count: 6,
              filters: {
                categories: [],
                price_band: "mid",
                fresh_days: 0,
                region: "ke",
                pickup_only: false
              },
              reason: "Complete the look"
            },
            {
              id: "more_from_shop",
              count: 8,
              filters: {
                categories: [],
                price_band: "mid",
                fresh_days: 0,
                region: "ke",
                pickup_only: false
              },
              reason: "More from this shop"
            }
          ],
          copy_style: { tone: "friendly", max_reason_len: 80 },
          version: "1.0-mvp"
        }
      when "profile"
        {
          plan_id: "control_profile_#{Time.current.strftime('%Y%m%d_%H%M%S')}",
          source: "control",
          ttl_seconds: 172800,
          page: "profile",
          sections: [
            {
              id: "top_picks_for_you",
              count: 12,
              filters: {
                categories: [],
                price_band: "mid",
                fresh_days: 0,
                region: "ke",
                pickup_only: false
              },
              reason: "Top picks for you"
            },
            {
              id: "new_in_favorites",
              count: 12,
              filters: {
                categories: [],
                price_band: "mid",
                fresh_days: 7,
                region: "ke",
                pickup_only: false
              },
              reason: "New in your favorites"
            },
            {
              id: "from_shops_you_like",
              count: 12,
              filters: {
                categories: [],
                price_band: "mid",
                fresh_days: 0,
                region: "ke",
                pickup_only: false
              },
              reason: "From shops you like"
            }
          ],
          copy_style: { tone: "friendly", max_reason_len: 80 },
          version: "1.0-mvp"
        }
      else
        self.for("home")
      end
    end
  end
end
