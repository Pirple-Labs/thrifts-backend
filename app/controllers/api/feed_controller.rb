# app/controllers/api/feed_controller.rb
# frozen_string_literal: true
module Api
  class FeedController < Api::BaseController
    skip_before_action :authenticate_user!, only: [:start, :next], raise: false

    TTL_SECONDS      = 300
    MAX_POOL         = 200
    MAX_SUPP_IMAGES  = 4
    FALLBACK_TTL_SEC = 60
    ALLOWED_PAGES    = %w[home pdp profile cart checkout].freeze

    # POST /api/feed/start
    def start
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      p      = feed_params
      limit  = clamp_limit(p[:limit])

      # Validate required params and rate limit
      unless validate_required_params(['page'])
        return
      end
      unless check_rate_limit(p[:user_id] || current_user&.id, request.remote_ip)
        return
      end

      # 1) Build snapshot with normalized page using SnapshotBuilder.build (OpenStructs)
      req_struct = OpenStruct.new(
        user_id:     p[:user_id],
        session_id:  (p[:session_id].presence || "anon_#{SecureRandom.hex(8)}"),
        page:        normalize_page(p[:page]),
        pid:         p[:pid],
        region:      p[:region],
        geohash6:    p[:geohash6],
        pickup_only: ActiveModel::Type::Boolean.new.cast(p[:pickup_only])
      )
      sess_struct = OpenStruct.new(
        id: p[:session_id],
        user_id: p[:user_id],
        last_search: nil
      )
      snapshot = Personalization::SnapshotBuilder.build(req_struct, sess_struct)

      # 2) Cache reuse
      fp  = Personalization::FingerprintCache.fingerprint(snapshot: snapshot, versions: versions_hash_for_fp)
      hit = Personalization::FingerprintCache.reuse_feed(fingerprint: fp, ttl_seconds: TTL_SECONDS)

      if hit.present?
        feed    = hit[:feed]
        items   = hit[:items]
        slice   = Personalization::Paginator.slice(items: items, cursor: nil, limit: limit)
        reasons = hit[:reasons].slice(*slice[:items])
        lite    = build_lite_products(slice[:items])

        return render json: sectioned_response(
          feed: feed,
          plan_id: (hit[:plan_id] || feed.plan_id || "control_v1"),
          items: slice[:items],
          lite: lite,
          reasons: reasons,
          slice: { index: 1, cursor: slice[:cursor], has_more: slice[:has_more] },
          ttl_seconds: TTL_SECONDS,
          is_cache_hit: true
        ), status: :ok
      end

      # 3) Build profile and session data for Operator
      profile = Personalization::ProfileStore.slice(p[:user_id])
      # Guard against nils in snapshot/profile when hashing
      safe_snapshot = (snapshot || {}).with_indifferent_access
      safe_profile  = (profile || {}).with_indifferent_access
      session_embed_summary = build_session_embed_summary(safe_snapshot[:session_id] || safe_snapshot["session_id"])
      profile_hash = Personalization::ProfileHasher.hash(safe_snapshot, safe_profile)
      
      # 4) Check for intent drift
      intent_drift = Personalization::IntentEngine.drift?(snapshot, snapshot, profile)
      
      # 5) Try to get plan from cache (allow force_fresh)
      force_fresh = params[:force_fresh].to_s == "true"
      plan = force_fresh ? nil : Personalization::PlanCache.get(p[:page], profile_hash)
      
      unless plan
        # 6) Fetch plan from Operator using new contract
        constraints = {
          p95_budget_ms: 1000,
          max_sections: 6
        }
        
        plan = Personalization::PlannerClient.fetch_plan(
          page: p[:page],
          snapshot: snapshot,
          profile: profile,
          session_embed_summary: session_embed_summary,
          constraints: constraints
        )
        
        if plan.nil?
          Rails.logger.error("PlannerClient returned nil plan, falling back to control plan")
          plan = Personalization::PlannerClient.control_plan(p[:page])
        end

        # 7) Validate plan
        validation_errors = Personalization::SectionValidator.validate_plan(plan, p[:page])
        if validation_errors.any?
          Rails.logger.error("Plan validation failed: #{validation_errors.join(', ')}")
          plan = Personalization::PlannerClient.control_plan(p[:page])
        end
        
        # 8) Store plan in cache
        Personalization::PlanCache.set(p[:page], profile_hash, plan, ttl: plan[:ttl_seconds] || 172800)
      end

      # 9) Execute plan sections using new contract
      sections = execute_plan_sections(plan, safe_snapshot, safe_profile, session_embed_summary)
      
      # 10) Flatten sections into ranked items for backward compatibility
      ranked = sections.flat_map { |section| section[:products] || [] }

      # 11) Persist + cache
      trace_versions = {
        prompt_version: "plan_dsl_v1.0-mvp",
        model_version: plan[:source] || "control",
        index_version: "v1.0"
      }

      plan_id = plan[:plan_id] || "control_v1"
      
      # Get experiment data for persistence
      experiment_key = ENV['EXP_HOME_RANKER'] == 'true' ? 'home_ranker_ab_2025q3' : nil
      variant = if experiment_key.present?
                  Personalization::ExperimentAssignment.get_assignment(
                    experiment_key: experiment_key,
                    user_id: snapshot["user_id"],
                    session_id: snapshot["session_id"]
                  )&.variant
                end
      
      feed, reasons_map = Personalization::SlateWriter.persist!(
        snapshot:     safe_snapshot,
        fingerprint:  fp,
        ranked_items: ranked,
        ttl_seconds:  TTL_SECONDS,
        versions:     trace_versions,
        plan_id:      plan_id,
        experiment_key: experiment_key,
        variant: variant
      )

      # Persist feed cache with plan sections and snapshot for hydration
      plan_sections_for_cache = plan.is_a?(Hash) ? (plan[:sections] || plan.dig(:page_plans, p[:page], :sections) || []) : []
      Personalization::FingerprintCache.store!(
        fingerprint: fp,
        feed:        feed,
        items:       ranked.map { _1[:id].to_s },
        reasons:     reasons_map,
        ttl_seconds: TTL_SECONDS,
        plan_sections: plan_sections_for_cache,
        snapshot: safe_snapshot
      )

      # 7) First slice
      slice_items = ranked.map { _1[:id].to_s }
      slice       = Personalization::Paginator.slice(items: slice_items, cursor: nil, limit: limit)
      lite        = build_lite_products(slice[:items])

      # 8) Cost tracking
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      total_cpu_seconds = end_time - start_time
      
      # Track API usage and costs
      Personalization::CostMeter.track_usage!(
        plan_id: plan_id,
        endpoint: '/api/feeds/start',
        cpu_seconds: total_cpu_seconds
      )

      # Build visible sections (trending + grid) and lazy injection plan
      trending = sections.find { |s| ["trending_near_you", "trending_in_category"].include?(s[:id].to_s) }
      # Ensure trending exists; if missing, execute a single trending section
      unless trending.present?
        trg_sec = execute_plan_sections({ sections: [ { id: "trending_near_you", count: 12, filters: {}, knobs: {} } ] }, safe_snapshot, safe_profile, session_embed_summary).first
        trending = trg_sec if trg_sec
      end

      visible_sections = []
      if trending.present?
        visible_sections << {
          id: trending[:id],
          type: "horizontal",
          title: trending[:title],
          reason: trending[:reason],
          products: trending[:products],
          count: trending[:products].count,
          cursor: nil,
          has_more: false
        }
      else
        # As a last resort, build a trending-like strip using popular fallback ids
        fallback_ids = Product.where("stock > 0").where(moderation_status: "approved").order(created_at: :desc).limit(12).pluck(:id).map(&:to_s)
        visible_sections << {
          id: "trending_near_you",
          type: "horizontal",
          title: "Trending near you",
          reason: "Popular picks",
          products: build_lite_products(fallback_ids),
          count: fallback_ids.count,
          cursor: nil,
          has_more: false
        }
      end

      visible_sections << {
        id: "grid",
        type: "grid",
        title: "For you",
        reason: nil,
        products: lite,
        count: lite.count,
        cursor: slice[:cursor],
        has_more: slice[:has_more]
      }

      if p[:page] == "home"
        # Ensure and include all additional strips with products now
        def build_or_fetch_section(id, title, count)
          exist = sections.find { |s| s[:id].to_s == id }
          return exist if exist&.dig(:products).present?
          execute_plan_sections({ sections: [ { id: id, count: count, filters: {}, knobs: {} } ] }, safe_snapshot, safe_profile, session_embed_summary).first
        end

        fresh = build_or_fetch_section("fresh_in_favorites", "New in favourites", 12)
        liked_viewed = build_or_fetch_section("lookalikes_since_viewed", "Since you liked", 12) || build_or_fetch_section("lookalikes", "Since you liked", 12)
        liked_purchased = build_or_fetch_section("lookalikes_since_purchased", "Complete the look", 12) || build_or_fetch_section("lookalikes", "Complete the look", 12)

        if fresh
          visible_sections << {
            id: fresh[:id],
            type: "horizontal",
            title: fresh[:title] || "New in favourites",
            reason: fresh[:reason],
            positionAfter: 12,
            products: fresh[:products],
            count: fresh[:products].count,
            cursor: nil,
            has_more: false
          }
        end
        if liked_viewed
          visible_sections << {
            id: liked_viewed[:id],
            type: "horizontal",
            title: liked_viewed[:title] || "Since you liked",
            reason: liked_viewed[:reason],
            positionAfter: 36,
            products: liked_viewed[:products],
            count: liked_viewed[:products].count,
            cursor: nil,
            has_more: false
          }
        end
        if liked_purchased
          visible_sections << {
            id: liked_purchased[:id],
            type: "horizontal",
            title: liked_purchased[:title] || "Complete the look",
            reason: liked_purchased[:reason],
            positionAfter: 60,
            products: liked_purchased[:products],
            count: liked_purchased[:products].count,
            cursor: nil,
            has_more: false
          }
        end
      end

      resp = {
        feed_id: feed.feed_uid,
        plan_id: plan_id,
        ttl_seconds: TTL_SECONDS,
        sections: visible_sections,
        trace: trace_versions,
        is_cache_hit: false,
        intent: nil
      }

      # Add cache headers and track performance
      add_cache_headers(self, 'lite_data', 5.minutes, 60.minutes)
      track_performance('/api/feeds/start', start_time, resp.to_json.bytesize)

      render json: resp, status: :ok

    rescue => e
      Rails.logger.error("[/api/feed/start] #{e.class}: #{e.message}\n#{e.backtrace&.first(3)&.join("\n")}")
      render json: popular_fallback(snapshot: safe_snapshot, limit: limit, reason: "unknown_error"), status: :ok
    end

    # POST /api/feed/next
    def next
      feed_id = params[:feed_id].to_s
      cursor  = params[:cursor].presence
      section_id = params[:section_id].presence
      limit   = clamp_limit(params[:limit])

      # Optional lightweight rate limit on hydration/pagination
      check_rate_limit(current_user&.id, request.remote_ip)

      feed = Feed.find_by(feed_uid: feed_id)
      return render json: { error: "feed not found" }, status: :not_found unless feed

      cached = Personalization::FingerprintCache.fetch_by_feed(feed: feed)
      # Section hydration path: hydrate a specific section on demand
      if section_id
        plan_sections = (cached && cached[:plan_sections]) || []
        raw = plan_sections.find { |s| (s.is_a?(Hash) && (s[:id].to_s == section_id || s["id"].to_s == section_id)) }
        unless raw
          return render json: { sections: [{ id: section_id, products: [], cursor: nil, has_more: false }] }, status: :ok
        end

        # Build context
        snapshot = (cached && cached[:snapshot]) || {}
        profile = Personalization::ProfileStore.slice(snapshot[:user_id] || snapshot["user_id"])
        session_embed_summary = build_session_embed_summary(snapshot[:session_id] || snapshot["session_id"] || feed.session_id)

        # Normalize section config keys
        sec_cfg = raw.respond_to?(:deep_symbolize_keys) ? raw.deep_symbolize_keys : raw
        sec_cfg[:count] ||= limit

        # Execute just this section
        single_plan = { sections: [sec_cfg] }
        sections = execute_plan_sections(single_plan, snapshot.symbolize_keys, profile, session_embed_summary)
        section = sections.first || { id: section_id, products: [] }

        return render json: {
          feed_id: feed.feed_uid,
          plan_id: cached&.dig(:plan_id) || feed.plan_id || "control_v1",
          sections: [
            {
              id: section[:id],
              products: section[:products],
              cursor: nil,
              has_more: false
            }
          ],
          is_cache_hit: true
        }, status: :ok
      end

      unless cached
        items   = feed.feed_items.order(:position).pluck(:product_id).map(&:to_s)
        reasons = feed.feed_items.each_with_object({}) { |fi, h| h[fi.product_id.to_s] = (fi.reason || "") }
        Personalization::FingerprintCache.store!(
          fingerprint: feed.fingerprint,
          feed:        feed,
          items:       items,
          reasons:     reasons,
          ttl_seconds: (feed.ttl_seconds || TTL_SECONDS)
        )
        cached = { items:, reasons: }
      end

      slice = Personalization::Paginator.slice(items: cached[:items], cursor:, limit:)
      lite  = build_lite_products(slice[:items])

      render json: sectioned_response(
        feed: feed,
        plan_id: cached&.dig(:plan_id) || feed.plan_id || "control_v1",
        items: slice[:items],
        lite: lite,
        reasons: cached[:reasons].slice(*slice[:items]),
        slice: { index: slice[:index], cursor: slice[:cursor], has_more: slice[:has_more] },
        ttl_seconds: (feed.ttl_seconds || TTL_SECONDS),
        is_cache_hit: true
      ), status: :ok
    end

    private

    def clamp_limit(val)
      (val.presence || 24).to_i.clamp(1, 60)
    end

    def normalize_page(page)
      pg = page.to_s
      return pg if ALLOWED_PAGES.include?(pg)
      "home"
    end

    def feed_params
      # Allow top-level keys, alias :session -> :session_id, and optionally flatten nested :feed
      allowed = [:page, :pid, :session_id, :user_id, :anonymous_id, :region, :geohash6, :pickup_only, :limit, :session]
      permitted = params.permit(*allowed, feed: allowed)

      # Start with top-level allowed keys only (excluding :session alias for now)
      top = permitted.slice(:page, :pid, :session_id, :user_id, :anonymous_id, :region, :geohash6, :pickup_only, :limit).to_h

      # Apply alias for session -> session_id (top-level first)
      top[:session_id] = top[:session_id].presence || permitted[:session].presence

      # If nested :feed is present, merge allowed keys (do not overwrite existing non-blank)
      if permitted[:feed].present?
        feed_sub = permitted[:feed]
        # Merge feed keys
        [:page, :pid, :session_id, :user_id, :anonymous_id, :region, :geohash6, :pickup_only, :limit].each do |k|
          val = feed_sub[k]
          top[k] = val if val.present? && top[k].blank?
        end
        # Apply alias inside feed: feed[:session] -> session_id
        top[:session_id] = top[:session_id].presence || feed_sub[:session].presence
      end

      top.with_indifferent_access
    end

    def versions_hash_for_fp
      { prompt_version: "qp_contract_v1", model_version: "ai_contract_v1", index_version: "vec_contract_v1" }
    end

    def build_session_embed_summary(session_id)
      # Simplified session embedding summary
      sid = session_id.to_s
      sid = "anon_#{SecureRandom.hex(8)}" if sid.blank?
      {
        topics: ["general_interest"],
        centroid_bucket: Digest::SHA256.hexdigest(sid)[0..11]
      }
    end

    def execute_plan_sections(plan, snapshot, profile, session_embed_summary)
      sections = []
      merchant_counts = {}
      
      # Handle both old and new plan formats
      plan_sections = plan[:sections] || plan.dig(:page_plans, snapshot[:page], :sections) || []
      
      plan_sections.each do |section_config|
        # Execute section retrieval
        candidates = retrieve_section_products(section_config, snapshot, profile, session_embed_summary)
        
        # Apply guardrails
        guardrails_result = Personalization::Guardrails.apply(
          candidates, 
          {
            snapshot: snapshot,
            profile: profile,
            merchant_counts: merchant_counts
          }
        )
        
        # Apply coordination if applicable
        coordinated_items = Personalization::Coordination.fill_if_applicable(
          guardrails_result[:filtered],
          section_config,
          snapshot,
          profile
        )
        
        # Take requested count
        final_items = coordinated_items.take(section_config[:count])
        
        # Update merchant counts
        final_items.each do |item|
          product = Product.find_by(id: item[:id])
          next unless product
          merchant_counts[product.shop_id] = (merchant_counts[product.shop_id] || 0) + 1
        end
        
        # Build section response
        section = {
          id: section_config[:id],
          title: section_config[:title] || section_config[:id].humanize,
          reason: section_config[:reason],
          products: Personalization::ResponseShaper.build_lite_products(
            final_items.map { |item| item[:id].to_s }
          ),
          pre_guard_candidates: candidates,
          guardrail_drops: guardrails_result[:drop_reasons],
          retrieval_latency: 0, # Would be measured in real implementation
          guardrails_latency: 0,
          coordination_latency: 0,
          total_latency: 0
        }
        
        sections << section
      end
      
      sections
    end

    def retrieve_section_products(section_config, snapshot, profile, session_embed_summary)
      # Route to appropriate retrieval strategy based on section ID
      case section_config[:id]
      when "session_picks", "search_results"
        Personalization::Retrieval::SearchFusion.run(
          section_config[:filters],
          section_config[:knobs] || {},
          {
            snapshot: snapshot,
            profile: profile,
            session_embed_summary: session_embed_summary
          }
        )
      when "lookalikes"
        Personalization::Retrieval::Lookalikes.run(
          section_config[:filters],
          section_config[:knobs] || {},
          {
            snapshot: snapshot,
            profile: profile,
            session_embed_summary: session_embed_summary
          }
        )
      when "trending_near_you", "trending_in_category"
        Personalization::Retrieval::Trending.run(
          section_config[:filters],
          section_config[:knobs] || {},
          {
            snapshot: snapshot,
            profile: profile,
            session_embed_summary: session_embed_summary
          }
        )
      else
        # Default to search fusion
        Personalization::Retrieval::SearchFusion.run(
          section_config[:filters],
          section_config[:knobs] || {},
          {
            snapshot: snapshot,
            profile: profile,
            session_embed_summary: session_embed_summary
          }
        )
      end
    end

    # ---------- JSON shaping helpers ----------
    # Sectioned response wrapper
    def sectioned_response(feed:, plan_id:, items:, lite:, reasons:, slice:, ttl_seconds:, is_cache_hit:, intent: nil, trace_versions: nil)
      response = {
        feed_id:     feed.feed_uid,
        plan_id:     plan_id,
        ttl_seconds: ttl_seconds,
        sections: [
          {
            id: "grid",
            reason: nil,
            products: lite
          }
        ],
        cursor: slice[:cursor],
        hasMore: slice[:has_more],
        trace: (trace_versions || { prompt_version: feed.prompt_version, model_version: feed.model_version, index_version: feed.index_version }),
        is_cache_hit: is_cache_hit,
        intent: intent
      }
      
      # Add experiment data if present
      if feed.experiment_key.present? && feed.variant.present?
        response[:experiment] = {
          key: feed.experiment_key,
          variant: feed.variant
        }
      end
      
      response
    end

    def coerce_images(val)
      arr =
        case val
        when Array then val
        when String
          begin
            parsed = JSON.parse(val)
            parsed.is_a?(Array) ? parsed : []
          rescue JSON::ParserError
            []
          end
        else
          []
        end
      arr.map { |u| u.to_s.presence }.compact.first(MAX_SUPP_IMAGES)
    end

    def main_image_or_fallback(main_image, supp_arr)
      (main_image.to_s.presence) || supp_arr.first.to_s.presence
    end

    # Minimal product shape for cards, preserving order
    def build_lite_products(ids_as_strings)
      ids = Array(ids_as_strings).map(&:to_i)
      return [] if ids.empty?

      records = ::Product
                  .includes(:shop)
                  .where(id: ids)
                  .select(:id, :name, :price, :main_image, :supplementary_images, :shop_id)

      by_id = {}
      records.each do |p|
        supp       = coerce_images(p.supplementary_images)
        main       = main_image_or_fallback(p.main_image, supp)
        image_alias = main || supp.first

        by_id[p.id] = {
          id:   p.id,
          name: p.name.to_s,
          price: p.price.to_s,
          image: image_alias.to_s,
          main_image: main.to_s.presence,
          supplementary_images: supp,
          shop: {
            id: p.shop_id,
            name: p.shop&.name.to_s,
            store_logo_url: p.shop&.store_logo_url.to_s.presence
          }
        }
      end

      ids.map { |pid| by_id[pid] }.compact
    end

    # Fallback that STILL returns a real feed_id and ALL sections populated
    def popular_fallback(snapshot:, limit:, reason:)
      snap = (snapshot || {}).with_indifferent_access
      snap[:page] ||= "home"
      snap[:session_id] ||= "anon_#{SecureRandom.hex(8)}"

      base_scope = Product.where("stock > 0")
                          .where(moderation_status: "approved")
                          .where(pickup_ready: true)

      # Build ids for each section
      trending_ids = base_scope.order(created_at: :desc).limit(12).pluck(:id).map(&:to_s)
      # Build a larger pool so fallback supports real pagination
      grid_pool_ids = base_scope.order(created_at: :desc).limit(MAX_POOL).pluck(:id).map(&:to_s)
      grid_slice    = Personalization::Paginator.slice(items: grid_pool_ids, cursor: nil, limit: limit)
      fresh_ids    = base_scope.order(Arel.sql('RANDOM()')).limit(12).pluck(:id).map(&:to_s)
      liked_v_ids  = base_scope.order(Arel.sql('RANDOM()')).limit(12).pluck(:id).map(&:to_s)
      liked_p_ids  = base_scope.order(Arel.sql('RANDOM()')).limit(12).pluck(:id).map(&:to_s)

      trace_versions = { prompt_version: "fallback", model_version: reason.to_s, index_version: "catalog" }
      fp = "fallback:#{Digest::SHA256.hexdigest([
        snap[:user_id].to_s,
        snap[:session_id].to_s,
        snap[:page].to_s,
        reason.to_s
      ].join("|"))}"

      # Persist feed using the full grid pool for stable pagination via /next
      ranked = grid_pool_ids.map { |id| { id: id } }
      plan_id = "control_fallback_v1"
      feed, _reasons_map = Personalization::SlateWriter.persist!(
        snapshot:     snap,
        fingerprint:  fp,
        ranked_items: ranked,
        ttl_seconds:  FALLBACK_TTL_SEC,
        versions:     trace_versions,
        plan_id:      plan_id
      )

      Personalization::FingerprintCache.store!(
        fingerprint: fp,
        feed:        feed,
        items:       grid_pool_ids,
        reasons:     {},
        ttl_seconds: FALLBACK_TTL_SEC
      )

      sections = []
      sections << {
        id: "trending_near_you",
        type: "horizontal",
        title: "Trending near you",
        reason: "Popular picks",
        products: build_lite_products(trending_ids),
        count: trending_ids.count,
        cursor: nil,
        has_more: false
      }
      sections << {
        id: "grid",
        type: "grid",
        title: "For you",
        reason: nil,
        products: build_lite_products(grid_slice[:items]),
        count: grid_slice[:items].count,
        cursor: grid_slice[:cursor],
        has_more: grid_slice[:has_more]
      }
      sections << {
        id: "fresh_in_favorites",
        type: "horizontal",
        title: "New in favourites",
        reason: "Fresh picks you may like",
        positionAfter: 12,
        products: build_lite_products(fresh_ids),
        count: fresh_ids.count,
        cursor: nil,
        has_more: false
      }
      sections << {
        id: "lookalikes_since_viewed",
        type: "horizontal",
        title: "Since you liked",
        reason: "Similar to your browsing",
        positionAfter: 36,
        products: build_lite_products(liked_v_ids),
        count: liked_v_ids.count,
        cursor: nil,
        has_more: false
      }
      sections << {
        id: "lookalikes_since_purchased",
        type: "horizontal",
        title: "Complete the look",
        reason: "Pairs well with your picks",
        positionAfter: 60,
        products: build_lite_products(liked_p_ids),
        count: liked_p_ids.count,
        cursor: nil,
        has_more: false
      }

      {
        feed_id: feed.feed_uid,
        plan_id: plan_id,
        ttl_seconds: FALLBACK_TTL_SEC,
        sections: sections,
        trace: trace_versions,
        is_cache_hit: false,
        intent: nil
      }
    end

    # ---- Utilities borrowed from DemoController ----
    def add_cache_headers(response, data_type, soft_ttl, hard_ttl)
      case data_type
      when 'lite_data', 'full_data', 'section_window'
        response.headers['Cache-Control'] = "public, max-age=#{soft_ttl.to_i}, s-maxage=#{hard_ttl.to_i}"
        response.headers['X-Cache-TTL'] = soft_ttl.to_i
        response.headers['X-Cache-Hard-TTL'] = hard_ttl.to_i
      end
      response.headers['X-Data-Type'] = data_type
    end

    def track_performance(endpoint, start_time_mono, response_size)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time_mono) * 1000.0)
      Rails.logger.info("[Performance] #{endpoint}: #{duration_ms.round(2)}ms, #{response_size} bytes")
      Rails.cache.write("metrics:#{endpoint}:#{Time.current.to_i}", { duration_ms:, response_size:, ts: Time.current }, expires_in: 1.hour)
    end

    def render_error(error_code, message, details = {}, status = :bad_request)
      render json: { error: error_code, message: message, details: details, timestamp: Time.current.iso8601 }, status: status
    end

    def validate_required_params(required_params)
      missing = required_params.select { |param| params[param].blank? }
      if missing.any?
        render_error('missing_parameters', "Missing required parameters: #{missing.join(', ')}", { missing: missing }, :bad_request)
        return false
      end
      true
    end

    def check_rate_limit(user_id, ip_address)
      # Per user rate limiting
      user_key = "rate_limit:user:#{user_id || 'guest'}"
      user_requests = Rails.cache.read(user_key) || 0
      if user_requests >= 100
        render_error('rate_limit_exceeded', 'Too many requests. Please try again later.', { limit: 100, window: '1 minute' }, :too_many_requests)
        return false
      end

      # Per IP rate limiting
      ip_key = "rate_limit:ip:#{ip_address}"
      ip_requests = Rails.cache.read(ip_key) || 0
      if ip_requests >= 1000
        render_error('rate_limit_exceeded', 'Too many requests from this IP. Please try again later.', { limit: 1000, window: '1 minute' }, :too_many_requests)
        return false
      end

      Rails.cache.write(user_key, user_requests + 1, expires_in: 1.minute)
      Rails.cache.write(ip_key, ip_requests + 1, expires_in: 1.minute)
      true
    end
  end
end
