# frozen_string_literal: true

require 'test_helper'

class Personalization::PlanDslContractTest < ActiveSupport::TestCase
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
  end

  test "snapshot builder creates valid snapshot" do
    snapshot = Personalization::SnapshotBuilder.build(@snapshot, {})
    
    assert_equal "home", snapshot[:page]
    assert_equal "ke", snapshot[:region]
    assert_equal false, snapshot[:pickup_only]
    assert_equal @user.id, snapshot[:user_id]
    assert_equal @session_id, snapshot[:session_id]
    assert_includes snapshot.keys, :views_10m
    assert_includes snapshot.keys, :recent_add_to_cart
    assert_includes snapshot.keys, :inactivity_bucket
  end

  test "profile store creates valid profile slice" do
    profile = Personalization::ProfileStore.slice(@user.id)
    
    assert_includes profile.keys, :price_band
    assert_includes profile.keys, :top_categories
    assert_includes profile.keys, :brand_top
    assert_includes profile.keys, :shop_top
    assert_includes profile.keys, :freshness_pref
    assert_includes profile.keys, :diversity_pref
    
    assert profile[:freshness_pref].between?(0, 1)
    assert profile[:diversity_pref].between?(0, 1)
  end

  test "profile hasher creates deterministic hash" do
    hash1 = Personalization::ProfileHasher.hash(@snapshot, @profile)
    hash2 = Personalization::ProfileHasher.hash(@snapshot, @profile)
    
    assert_equal hash1, hash2
    assert hash1.is_a?(String)
    assert hash1.length > 0
  end

  test "intent engine detects drift correctly" do
    # Test with new search
    snapshot_with_search = @snapshot.merge(last_search: "laptop")
    drift = Personalization::IntentEngine.drift?(@snapshot, snapshot_with_search, @profile)
    assert drift
    
    # Test without drift
    drift = Personalization::IntentEngine.drift?(@snapshot, @snapshot, @profile)
    assert_not drift
  end

  test "plan cache stores and retrieves plans" do
    plan = {
      plan_id: "test_plan_123",
      ttl_seconds: 3600,
      source: "control",
      page_plans: {
        "home" => {
          version: "1.2",
          page: "home",
          sections: []
        }
      }
    }
    
    # Store plan
    Personalization::PlanCache.set("home", "test_hash", plan, ttl: 3600)
    
    # Retrieve plan
    retrieved_plan = Personalization::PlanCache.get("home", "test_hash")
    assert_equal plan[:plan_id], retrieved_plan[:plan_id]
    assert_equal plan[:source], retrieved_plan[:source]
  end

  test "search fusion returns valid results" do
    filters = {
      region: "ke",
      pickup_only: false,
      price_band: "mid"
    }
    knobs = {
      alpha_rrf: 0.6,
      lambda_diversity: 0.3,
      beta_price_tilt: 0.2
    }
    context = {
      snapshot: @snapshot,
      profile: @profile,
      session_embed_summary: { topic_slate: ["general"], centroid_hash: "abc123" }
    }
    
    results = Personalization::Retrieval::SearchFusion.run(filters, knobs, context)
    
    assert results.is_a?(Array)
    results.each do |result|
      assert_includes result.keys, :id
      assert_includes result.keys, :score
      assert result[:id].is_a?(Integer)
      assert result[:score].is_a?(Numeric)
    end
  end

  test "guardrails filters products correctly" do
    # Create test products
    product1 = products(:one)
    product2 = products(:two)
    
    candidates = [
      { id: product1.id, score: 0.8 },
      { id: product2.id, score: 0.6 }
    ]
    
    context = {
      snapshot: @snapshot,
      profile: @profile,
      merchant_counts: {}
    }
    
    result = Personalization::Guardrails.apply(candidates, context)
    
    assert_includes result.keys, :filtered
    assert_includes result.keys, :drop_reasons
    assert result[:filtered].is_a?(Array)
    assert result[:drop_reasons].is_a?(Hash)
  end

  test "coordination fills complementary items" do
    items = [
      { id: 1, score: 0.8 },
      { id: 2, score: 0.6 }
    ]
    
    section = {
      coordination_template: {
        slots: ["shoes", "bag"],
        w: { emb: 0.4, copurch: 0.3, attr: 0.2, profile: 0.1 }
      },
      coordination: {
        caps: { per_merchant: 2, per_viewport: 2 }
      }
    }
    
    coordinated = Personalization::Coordination.fill_if_applicable(
      items, section, @snapshot, @profile
    )
    
    assert coordinated.is_a?(Array)
  end

  test "response shaper creates valid response" do
    sections = [
      {
        id: "session_picks",
        title: "Session Picks",
        reason: "Based on your recent activity",
        products: [
          { id: 1, name: "Product 1", price: "100", image: "image1.jpg" },
          { id: 2, name: "Product 2", price: "200", image: "image2.jpg" }
        ]
      }
    ]
    
    response = Personalization::ResponseShaper.sectioned_response(
      feed: feeds(:one),
      plan_id: "test_plan",
      sections: sections,
      ttl_seconds: 3600,
      is_cache_hit: false
    )
    
    assert_includes response.keys, :feed_id
    assert_includes response.keys, :plan_id
    assert_includes response.keys, :sections
    assert_includes response.keys, :ttl_seconds
    assert_includes response.keys, :is_cache_hit
    
    assert response[:sections].is_a?(Array)
    assert_equal 1, response[:sections].count
    assert_equal "session_picks", response[:sections].first[:id]
  end

  test "planner client generates control plan" do
    # Test control plan generation
    plan = Personalization::PlannerClient.generate_control_plan("home")
    
    assert_includes plan.keys, :plan_id
    assert_includes plan.keys, :ttl_seconds
    assert_includes plan.keys, :source
    assert_includes plan.keys, :page_plans
    
    assert_equal "control", plan[:source]
    assert plan[:page_plans].key?("home")
    
    home_plan = plan[:page_plans]["home"]
    assert_equal "1.2", home_plan[:version]
    assert_equal "home", home_plan[:page]
    assert home_plan[:sections].is_a?(Array)
    assert home_plan[:sections].any?
  end

  test "plan dsl contract integration" do
    # Test the full contract flow
    snapshot = Personalization::SnapshotBuilder.build(@snapshot, {})
    profile = Personalization::ProfileStore.slice(@user.id)
    profile_hash = Personalization::ProfileHasher.hash(snapshot, profile)
    
    # This should work without errors
    assert snapshot.present?
    assert profile.present?
    assert profile_hash.present?
    
    # Test plan cache operations
    plan = Personalization::PlannerClient.generate_control_plan("home")
    Personalization::PlanCache.set("home", profile_hash, plan)
    retrieved_plan = Personalization::PlanCache.get("home", profile_hash)
    
    assert_equal plan[:plan_id], retrieved_plan[:plan_id]
  end
end

