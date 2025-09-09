# frozen_string_literal: true

require 'test_helper'
require 'webmock/minitest'

class Personalization::OperatorContractTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @session_id = "test_session_123"
    @snapshot = {
      page: "home",
      region: "ke",
      pickup_only: false,
      user_id: @user.id,
      session_id: @session_id,
      views_10m: [],
      recent_add_to_cart: false,
      inactivity_bucket: "active",
      pid: nil
    }
    @profile = {
      price_band: "mid",
      top_categories: ["Electronics", "Fashion"],
      brand_top: ["Apple", "Nike"],
      shop_top: ["TechStore", "FashionHub"],
      freshness_pref: 0.6,
      diversity_pref: 0.7
    }
    @session_embed_summary = {
      topics: ["electronics", "fashion"],
      centroid_bucket: "v3-bkt-12"
    }
    @constraints = {
      p95_budget_ms: 1000,
      max_sections: 6
    }
  end

  test "happy path - successful plan generation" do
    # Mock successful Operator response
    operator_response = {
      plan_id: "plan_2025-01-15T10:30:00Z_ab14cd09_home_v1",
      source: "llm",
      ttl_seconds: 172800,
      page: "home",
      sections: [
        {
          id: "session_picks",
          count: 12,
          filters: {
            categories: ["electronics"],
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
            categories: ["electronics"],
            price_band: "mid",
            fresh_days: 30,
            region: "ke",
            pickup_only: false
          },
          reason: "Similar to what you've been browsing"
        }
      ],
      copy_style: { tone: "friendly", max_reason_len: 80 },
      version: "1.0-mvp"
    }

    stub_request(:post, "https://operator.internal/operator/query-pack")
      .with(
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'Authorization' => /Bearer .+/,
          'X-Request-Id' => /.+/,
          'X-Plan-DSL-Version' => '1.0-mvp'
        }
      )
      .to_return(
        status: 200,
        body: operator_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = Personalization::PlannerClient.fetch_plan(
      page: "home",
      snapshot: @snapshot,
      profile: @profile,
      session_embed_summary: @session_embed_summary,
      constraints: @constraints
    )

    assert_equal "llm", result[:source]
    assert_equal "home", result[:page]
    assert_equal 2, result[:sections].length
    assert_equal "session_picks", result[:sections].first[:id]
    assert_equal 12, result[:sections].first[:count]
  end

  test "control fallback on timeout" do
    stub_request(:post, "https://operator.internal/operator/query-pack")
      .to_timeout

    result = Personalization::PlannerClient.fetch_plan(
      page: "home",
      snapshot: @snapshot,
      profile: @profile,
      session_embed_summary: @session_embed_summary,
      constraints: @constraints
    )

    assert_equal "control", result[:source]
    assert_equal "home", result[:page]
    assert result[:sections].any?
  end

  test "control fallback on 400 schema validation error" do
    error_response = {
      error: {
        code: "SCHEMA_INVALID",
        message: "Invalid section ID",
        details: { field: "sections[0].id", reason: "unknown_section" }
      }
    }

    stub_request(:post, "https://operator.internal/operator/query-pack")
      .to_return(
        status: 400,
        body: error_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = Personalization::PlannerClient.fetch_plan(
      page: "home",
      snapshot: @snapshot,
      profile: @profile,
      session_embed_summary: @session_embed_summary,
      constraints: @constraints
    )

    assert_equal "control", result[:source]
    assert_equal "home", result[:page]
  end

  test "control fallback on 401 authentication error" do
    error_response = {
      error: {
        code: "AUTH_FAILED",
        message: "Invalid JWT token"
      }
    }

    stub_request(:post, "https://operator.internal/operator/query-pack")
      .to_return(
        status: 401,
        body: error_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = Personalization::PlannerClient.fetch_plan(
      page: "home",
      snapshot: @snapshot,
      profile: @profile,
      session_embed_summary: @session_embed_summary,
      constraints: @constraints
    )

    assert_equal "control", result[:source]
    assert_equal "home", result[:page]
  end

  test "control fallback on 5xx server error with retry" do
    stub_request(:post, "https://operator.internal/operator/query-pack")
      .to_return(
        { status: 500, body: "Internal Server Error" },
        { status: 200, body: { source: "llm", page: "home", sections: [] }.to_json }
      )

    result = Personalization::PlannerClient.fetch_plan(
      page: "home",
      snapshot: @snapshot,
      profile: @profile,
      session_embed_summary: @session_embed_summary,
      constraints: @constraints
    )

    assert_equal "llm", result[:source]
    assert_equal "home", result[:page]
  end

  test "request payload format matches contract" do
    expected_payload = {
      page: "home",
      snapshot: {
        region: "ke",
        pickup_only: false,
        last_search: "",
        views_10m: 0,
        recent_add_to_cart: false,
        inactivity_bucket: "0_10m",
        pid: nil
      },
      profile: @profile,
      constraints: @constraints,
      session_embed_summary: @session_embed_summary,
      plan_cache_hint: {
        profile_hash: Personalization::ProfileHasher.hash(@snapshot, @profile),
        ttl_seconds: 172800
      }
    }

    stub_request(:post, "https://operator.internal/operator/query-pack")
      .with(body: expected_payload.to_json)
      .to_return(
        status: 200,
        body: { source: "llm", page: "home", sections: [] }.to_json
      )

    Personalization::PlannerClient.fetch_plan(
      page: "home",
      snapshot: @snapshot,
      profile: @profile,
      session_embed_summary: @session_embed_summary,
      constraints: @constraints
    )

    assert_requested(:post, "https://operator.internal/operator/query-pack")
  end

  test "section validator validates allowed sections" do
    # Valid plan
    valid_plan = {
      sections: [
        { id: "session_picks", count: 12, filters: {}, reason: "Test" },
        { id: "lookalikes", count: 12, filters: {}, reason: "Test" }
      ]
    }
    
    errors = Personalization::SectionValidator.validate_plan(valid_plan, "home")
    assert_empty errors

    # Invalid plan with disallowed section
    invalid_plan = {
      sections: [
        { id: "invalid_section", count: 12, filters: {}, reason: "Test" }
      ]
    }
    
    errors = Personalization::SectionValidator.validate_plan(invalid_plan, "home")
    assert_includes errors.first, "Invalid section ID 'invalid_section'"
  end

  test "section validator validates section count limits" do
    # Too many sections
    plan_with_too_many_sections = {
      sections: Array.new(7) { { id: "session_picks", count: 12, filters: {}, reason: "Test" } }
    }
    
    errors = Personalization::SectionValidator.validate_plan(plan_with_too_many_sections, "home")
    assert_includes errors.first, "Too many sections: 7 (max 6)"
  end

  test "section validator validates reason length" do
    plan_with_long_reason = {
      sections: [
        { 
          id: "session_picks", 
          count: 12, 
          filters: {}, 
          reason: "A" * 81  # 81 characters, over limit of 80
        }
      ]
    }
    
    errors = Personalization::SectionValidator.validate_plan(plan_with_long_reason, "home")
    assert_includes errors.first, "Reason too long (81 chars, max 80)"
  end

  test "control plan generation for all pages" do
    %w[home search pdp profile].each do |page|
      plan = Personalization::PlannerClient.control_plan(page)
      
      assert_equal "control", plan[:source]
      assert_equal page, plan[:page]
      assert_equal "1.0-mvp", plan[:version]
      assert plan[:sections].is_a?(Array)
      assert plan[:sections].any?
      
      # Validate all sections are allowed for this page
      allowed_sections = Personalization::SectionValidator.allowed_sections_for_page(page)
      plan[:sections].each do |section|
        assert_includes allowed_sections, section[:id]
      end
    end
  end

  test "JWT token generation" do
    token = Personalization::PlannerClient.send(:generate_jwt_token)
    
    assert token.present?
    assert token.is_a?(String)
    
    # Decode and validate JWT payload
    decoded = JWT.decode(token, Personalization::PlannerClient.send(:jwt_secret), true, { algorithm: 'HS256' })
    payload = decoded[0]
    
    assert_equal "rails.personalization", payload["iss"]
    assert_equal "operator.personalization", payload["aud"]
    assert payload["exp"] > Time.current.to_i
  end

  test "request ID propagation" do
    request_id = "test-request-123"
    
    stub_request(:post, "https://operator.internal/operator/query-pack")
      .with(headers: { 'X-Request-Id' => request_id })
      .to_return(
        status: 200,
        body: { source: "llm", page: "home", sections: [] }.to_json
      )

    # Mock Current.request_id
    Current.stub(:request_id, request_id) do
      Personalization::PlannerClient.fetch_plan(
        page: "home",
        snapshot: @snapshot,
        profile: @profile,
        session_embed_summary: @session_embed_summary,
        constraints: @constraints
      )
    end

    assert_requested(:post, "https://operator.internal/operator/query-pack")
  end
end

