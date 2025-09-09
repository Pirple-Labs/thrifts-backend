# frozen_string_literal: true

module Api
  class PlanDslController < Api::BaseController
    skip_before_action :authenticate_user!, only: [:start], raise: false

    TTL_SECONDS = 300
    MAX_POOL = 200
    FALLBACK_TTL_SEC = 60
    ALLOWED_PAGES = %w[home search pdp profile].freeze

    # POST /api/plan-dsl/start
    def start
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      p = plan_dsl_params
      
      # 1) Build snapshot with normalized page
      snapshot = Personalization::SnapshotBuilder.build(
        user_id: p[:user_id],
        session_id: p[:session_id],
        page: normalize_page(p[:page]),
        pid: p[:pid],
        region: p[:region],
        geohash6: p[:geohash6],
        pickup_only: ActiveModel::Type::Boolean.new.cast(p[:pickup_only])
      )

      # 2) Build profile slice
      profile = Personalization::ProfileStore.slice(p[:user_id])
      
      # 3) Create session embedding summary
      session_embed_summary = build_session_embed_summary(p[:session_id])
      
      # 4) Compute profile hash
      profile_hash = Personalization::ProfileHasher.hash(snapshot, profile)
      
      # 5) Check for intent drift
      intent_drift = Personalization::IntentEngine.drift?(snapshot, snapshot, profile)
      
      # 6) Try to get plan from cache
      plan = Personalization::PlanCache.get(p[:page], profile_hash)
      
      unless plan
        # 7) Fetch plan from Operator using new contract
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
        
        # 8) Validate plan
        validation_errors = Personalization::SectionValidator.validate_plan(plan, p[:page])
        if validation_errors.any?
          Rails.logger.error("Plan validation failed: #{validation_errors.join(', ')}")
          plan = Personalization::PlannerClient.control_plan(p[:page])
        end
        
        # 9) Store plan in cache
        Personalization::PlanCache.set(p[:page], profile_hash, plan, ttl: plan[:ttl_seconds] || 172800)
      end

      # 10) Execute plan sections (updated for new contract)
      sections = execute_plan_sections(plan, snapshot, profile, session_embed_summary)
      
      # 10) Persist exposures
      feed, reasons_map = persist_feed_exposures(
        snapshot: snapshot,
        profile_hash: profile_hash,
        plan: plan,
        sections: sections
      )

      # 11) Shape response
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      total_latency = ((end_time - start_time) * 1000).round(2)
      
      render json: {
        feed_id: feed.feed_uid,
        plan_id: plan[:plan_id],
        ttl_seconds: plan[:ttl_seconds] || 172800,
        sections: sections.map do |section|
          {
            id: section[:id],
            title: section[:title],
            reason: section[:reason],
            products: section[:products],
            count: section[:products].count
          }
        end,
        metadata: {
          generated_at: Time.current,
          cache_hit: plan.present?,
          total_latency_ms: total_latency,
          profile_hash: profile_hash,
          intent_drift: intent_drift
        }
      }, status: :ok

    rescue => e
      Rails.logger.error("[/api/plan-dsl/start] #{e.class}: #{e.message}\n#{e.backtrace&.first(3)&.join("\n")}")
      render json: { error: "Internal server error" }, status: :internal_server_error
    end

    private

    def plan_dsl_params
      params.permit(:page, :pid, :session_id, :user_id, :region, :geohash6, :pickup_only)
    end

    def normalize_page(page)
      pg = page.to_s
      return pg if ALLOWED_PAGES.include?(pg)
      "home"
    end

    def build_session_embed_summary(session_id)
      # Simplified session embedding summary
      # In a real implementation, this would use actual embeddings
      {
        topic_slate: ["general_interest"],
        centroid_hash: Digest::SHA256.hexdigest(session_id)[0..11],
        embedding_version: "v1.0"
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
          section_config[:knobs],
          {
            snapshot: snapshot,
            profile: profile,
            session_embed_summary: session_embed_summary
          }
        )
      when "lookalikes"
        Personalization::Retrieval::Lookalikes.run(
          section_config[:filters],
          section_config[:knobs],
          {
            snapshot: snapshot,
            profile: profile,
            session_embed_summary: session_embed_summary
          }
        )
      when "trending_near_you", "trending_in_category"
        Personalization::Retrieval::Trending.run(
          section_config[:filters],
          section_config[:knobs],
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
          section_config[:knobs],
          {
            snapshot: snapshot,
            profile: profile,
            session_embed_summary: session_embed_summary
          }
        )
      end
    end

    def persist_feed_exposures(snapshot:, profile_hash:, plan:, sections:)
      # Create feed record
      feed = Feed.create!(
        feed_uid: SecureRandom.uuid,
        user_id: snapshot[:user_id],
        session_id: snapshot[:session_id],
        page: snapshot[:page],
        plan_id: plan[:plan_id],
        experiment_key: nil,
        variant: plan[:source],
        intent_label: nil,
        intent_confidence: nil,
        constraints: {
          pickup_only: snapshot[:pickup_only],
          region: snapshot[:region],
          geohash6: snapshot[:geohash6]
        }.compact,
        ttl_seconds: plan[:ttl_seconds] || 172800,
        is_cache_hit: false,
        prompt_version: "plan_dsl_v1.2",
        model_version: plan[:source] || "control",
        index_version: "v1.0",
        fingerprint: profile_hash
      )

      # Create feed exposures for each section
      reasons_map = {}
      sections.each do |section|
        section[:products].each_with_index do |product, position|
          # Create feed exposure record
          FeedExposure.create!(
            feed: feed,
            product_id: product[:id],
            section_id: section[:id],
            position: position + 1,
            profile_hash: profile_hash,
            reason_hash: Digest::SHA256.hexdigest(section[:reason] || ""),
            pre_guard_candidates: section[:pre_guard_candidates] || [],
            guardrail_drops: section[:guardrail_drops] || {},
            propensity: 1.0, # Would be calculated in real implementation
            latency_ms_retrieval: section[:retrieval_latency] || 0,
            latency_ms_guardrails: section[:guardrails_latency] || 0,
            latency_ms_coord: section[:coordination_latency] || 0,
            latency_ms_total: section[:total_latency] || 0
          )
          
          reasons_map[product[:id].to_s] = section[:reason] || ""
        end
      end

      [feed, reasons_map]
    end
  end
end
