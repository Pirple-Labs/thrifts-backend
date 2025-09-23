# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_16_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"
  enable_extension "vector"

  create_table "api_usage", force: :cascade do |t|
    t.string "plan_id", null: false
    t.string "endpoint", null: false
    t.date "ts", null: false
    t.integer "calls", default: 0, null: false
    t.decimal "gpu_seconds", precision: 12, scale: 3, default: "0.0", null: false
    t.decimal "cpu_seconds", precision: 12, scale: 3, default: "0.0", null: false
    t.integer "tokens", default: 0, null: false
    t.decimal "est_cost_usd", precision: 12, scale: 4, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint", "ts"], name: "idx_api_usage_endpoint_date"
    t.index ["plan_id", "endpoint", "ts"], name: "idx_api_usage_unique", unique: true
    t.index ["ts", "plan_id"], name: "idx_api_usage_date_plan"
    t.check_constraint "calls >= 0", name: "chk_api_usage_calls_positive"
    t.check_constraint "cpu_seconds >= 0::numeric", name: "chk_api_usage_cpu_positive"
    t.check_constraint "endpoint::text = ANY (ARRAY['/api/feeds/start'::character varying::text, '/api/feeds/next'::character varying::text, '/api/events'::character varying::text])", name: "chk_api_usage_endpoint"
    t.check_constraint "est_cost_usd >= 0::numeric", name: "chk_api_usage_cost_positive"
    t.check_constraint "gpu_seconds >= 0::numeric", name: "chk_api_usage_gpu_positive"
    t.check_constraint "tokens >= 0", name: "chk_api_usage_tokens_positive"
  end

  create_table "brands", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category"
    t.string "specialization"
    t.text "description"
    t.index ["category"], name: "index_brands_on_category"
    t.index ["specialization"], name: "index_brands_on_specialization"
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_cart_items_on_product_id"
    t.index ["user_id"], name: "index_cart_items_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "complementary_products", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "complementary_product_id", null: false
    t.string "triggered_by"
    t.float "score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_complementary_products_on_product_id"
  end

  create_table "conditions", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "delivery_addresses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "nickname"
    t.string "phone"
    t.string "location"
    t.string "pickup_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_delivery_addresses_on_user_id"
  end

  create_table "delivery_modes", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "events", force: :cascade do |t|
    t.string "event_id", null: false
    t.bigint "user_id"
    t.string "anonymous_id"
    t.string "session_id", null: false
    t.string "event_name", null: false
    t.datetime "timestamp_utc", null: false
    t.datetime "received_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "page", null: false
    t.string "region", null: false
    t.string "geohash6"
    t.string "schema_version", default: "v1", null: false
    t.jsonb "payload", default: {}, null: false
    t.index ["event_id"], name: "index_events_on_event_id", unique: true
    t.index ["event_name", "timestamp_utc"], name: "index_events_on_name_time"
    t.index ["payload"], name: "index_events_on_payload_gin", using: :gin
    t.index ["user_id", "session_id", "timestamp_utc"], name: "index_events_on_user_session_time"
    t.index ["user_id"], name: "index_events_on_user_id"
    t.check_constraint "page::text = ANY (ARRAY['home'::character varying::text, 'pdp'::character varying::text, 'profile'::character varying::text, 'cart'::character varying::text, 'checkout'::character varying::text, 'search'::character varying::text])", name: "chk_events_page"
    t.check_constraint "schema_version::text = ANY (ARRAY['v1'::character varying::text, 'v2'::character varying::text])", name: "chk_events_schema_version"
    t.check_constraint "timestamp_utc <= (received_at + 'PT10M'::interval)", name: "chk_events_timestamp_reasonable"
  end

  create_table "experiment_assignments", force: :cascade do |t|
    t.bigint "experiment_id", null: false
    t.bigint "user_id"
    t.string "session_id"
    t.string "variant", null: false
    t.datetime "assigned_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["experiment_id", "session_id"], name: "index_experiment_assignments_on_experiment_id_and_session_id", unique: true, where: "(session_id IS NOT NULL)"
    t.index ["experiment_id", "user_id"], name: "index_experiment_assignments_on_experiment_id_and_user_id", unique: true, where: "(user_id IS NOT NULL)"
    t.index ["experiment_id"], name: "index_experiment_assignments_on_experiment_id"
    t.index ["session_id", "assigned_at"], name: "idx_experiment_assignments_session_time"
    t.index ["user_id", "assigned_at"], name: "idx_experiment_assignments_user_time"
    t.index ["variant", "assigned_at"], name: "idx_experiment_assignments_variant_time"
    t.check_constraint "variant::text = ANY (ARRAY['control'::character varying::text, 'operator'::character varying::text])", name: "check_assignments_variant"
  end

  create_table "experiments", force: :cascade do |t|
    t.string "key", null: false
    t.string "status", default: "draft", null: false
    t.integer "traffic_pct", default: 50, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "idx_experiments_key_unique", unique: true
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'running'::character varying::text, 'paused'::character varying::text, 'complete'::character varying::text])", name: "check_experiments_status"
    t.check_constraint "traffic_pct >= 0 AND traffic_pct <= 100", name: "check_experiments_traffic_pct"
  end

  create_table "exposure_outcomes", force: :cascade do |t|
    t.string "feed_uid", null: false
    t.string "plan_id", null: false
    t.string "section", null: false
    t.bigint "product_id", null: false
    t.integer "position", null: false
    t.boolean "clicked_5m", default: false, null: false
    t.boolean "atc_30m", default: false, null: false
    t.boolean "purchased_24h", default: false, null: false
    t.float "item_weight_w1", default: 0.0, null: false
    t.datetime "window_start", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "window_end", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feed_uid", "plan_id", "section", "product_id", "position"], name: "idx_exposure_tuple"
  end

  create_table "feed_exposures", force: :cascade do |t|
    t.bigint "feed_id", null: false
    t.bigint "product_id", null: false
    t.string "section_id", null: false
    t.integer "position", null: false
    t.string "profile_hash", null: false
    t.string "reason_hash", null: false
    t.jsonb "pre_guard_candidates", default: {}
    t.jsonb "guardrail_drops", default: {}
    t.float "propensity", default: 1.0, null: false
    t.integer "latency_ms_retrieval", default: 0, null: false
    t.integer "latency_ms_guardrails", default: 0, null: false
    t.integer "latency_ms_coord", default: 0, null: false
    t.integer "latency_ms_total", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feed_id", "section_id", "position"], name: "index_feed_exposures_on_feed_id_and_section_id_and_position"
    t.index ["feed_id", "section_id"], name: "idx_feed_exposures_feed_section"
    t.index ["feed_id"], name: "index_feed_exposures_on_feed_id"
    t.index ["guardrail_drops"], name: "index_feed_exposures_on_guardrail_drops", using: :gin
    t.index ["latency_ms_total"], name: "index_feed_exposures_on_latency_ms_total"
    t.index ["pre_guard_candidates"], name: "index_feed_exposures_on_pre_guard_candidates", using: :gin
    t.index ["product_id"], name: "index_feed_exposures_on_product_id"
    t.index ["profile_hash"], name: "index_feed_exposures_on_profile_hash"
    t.index ["propensity"], name: "index_feed_exposures_on_propensity"
    t.index ["reason_hash"], name: "index_feed_exposures_on_reason_hash"
    t.index ["section_id", "position"], name: "index_feed_exposures_on_section_id_and_position"
  end

  create_table "feed_items", force: :cascade do |t|
    t.bigint "feed_id", null: false
    t.bigint "product_id", null: false
    t.string "section"
    t.integer "position"
    t.text "reason"
    t.text "matched_phrase"
    t.float "vec_score"
    t.float "weight"
    t.string "role"
    t.float "final_score"
    t.float "distance_km"
    t.float "local_pop_z"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feed_id"], name: "index_feed_items_on_feed_id"
    t.index ["product_id", "created_at"], name: "idx_feed_items_product_time"
    t.index ["product_id"], name: "index_feed_items_on_product_id"
    t.index ["section", "position"], name: "idx_feed_items_section_position"
    t.check_constraint "\"position\" >= 0", name: "chk_feed_items_position_positive"
    t.check_constraint "role::text = ANY (ARRAY['search'::character varying::text, 'trending'::character varying::text, 'similar'::character varying::text, 'image_search'::character varying::text, 'recommendation'::character varying::text, 'fallback'::character varying::text])", name: "chk_feed_items_role"
    t.check_constraint "section::text = ANY (ARRAY['grid'::character varying::text, 'trending'::character varying::text, 'search_results'::character varying::text, 'recommendations'::character varying::text])", name: "chk_feed_items_section"
    t.check_constraint "vec_score >= 0::double precision AND vec_score <= 1::double precision", name: "chk_feed_items_vec_score_range"
  end

  create_table "feeds", force: :cascade do |t|
    t.string "feed_uid"
    t.bigint "user_id"
    t.string "session_id"
    t.string "page"
    t.string "intent_label"
    t.float "intent_confidence"
    t.jsonb "constraints"
    t.integer "ttl_seconds"
    t.boolean "is_cache_hit"
    t.string "prompt_version"
    t.string "model_version"
    t.string "index_version"
    t.string "fingerprint"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "plan_id"
    t.string "experiment_key"
    t.string "variant"
    t.index ["experiment_key", "variant"], name: "idx_feeds_experiment"
    t.index ["plan_id", "created_at"], name: "idx_feeds_plan_time"
    t.index ["plan_id"], name: "index_feeds_on_plan_id"
    t.index ["session_id", "created_at"], name: "idx_feeds_session_time"
    t.index ["user_id", "created_at"], name: "idx_feeds_user_time"
    t.index ["user_id"], name: "index_feeds_on_user_id"
    t.check_constraint "is_cache_hit = ANY (ARRAY[true, false])", name: "chk_feeds_is_cache_hit"
    t.check_constraint "page::text = ANY (ARRAY['home'::character varying::text, 'pdp'::character varying::text, 'profile'::character varying::text, 'cart'::character varying::text, 'checkout'::character varying::text, 'search'::character varying::text])", name: "chk_feeds_page"
    t.check_constraint "ttl_seconds > 0", name: "chk_feeds_ttl_positive"
    t.check_constraint "variant::text = ANY (ARRAY['control'::character varying::text, 'operator'::character varying::text, 'llm'::character varying::text])", name: "check_feeds_variant"
  end

  create_table "hint_resolutions", force: :cascade do |t|
    t.string "request_id", null: false
    t.string "page", null: false
    t.string "section_id", null: false
    t.text "hint_text", null: false
    t.bigint "resolved_type_id"
    t.decimal "confidence", precision: 3, scale: 2
    t.string "locale", default: "en"
    t.boolean "inventory_supported", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_hint_resolutions_on_created_at"
    t.index ["hint_text", "confidence"], name: "index_hint_resolutions_on_hint_text_and_confidence"
    t.index ["request_id", "section_id"], name: "index_hint_resolutions_on_request_id_and_section_id"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "exp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "merchant_payments", force: :cascade do |t|
    t.bigint "payment_id", null: false
    t.bigint "shop_id", null: false
    t.bigint "order_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "status", default: "escrowed", null: false
    t.datetime "escrowed_at"
    t.datetime "released_at"
    t.datetime "transferred_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_merchant_payments_on_order_id"
    t.index ["payment_id"], name: "index_merchant_payments_on_payment_id"
    t.index ["shop_id"], name: "index_merchant_payments_on_shop_id"
  end

  create_table "merchant_wallets", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.decimal "balance", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id"], name: "index_merchant_wallets_on_shop_id", unique: true
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity"
    t.decimal "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "status", default: "pending"
    t.integer "total_items", default: 0
    t.decimal "total_price", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "shop_id", null: false
    t.bigint "delivery_address_id", null: false
    t.bigint "payment_id", null: false
    t.index ["delivery_address_id"], name: "index_orders_on_delivery_address_id"
    t.index ["payment_id"], name: "index_orders_on_payment_id"
    t.index ["shop_id"], name: "index_orders_on_shop_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "payment_methods", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "total_amount", precision: 10, scale: 2, null: false
    t.string "status", default: "pending", null: false
    t.string "mpesa_checkout_request_id"
    t.string "mpesa_receipt_number"
    t.string "phone_number_used"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "amount", null: false
    t.string "gateway", default: "mpesa", null: false
    t.string "mpesa_merchant_request_id"
    t.integer "result_code"
    t.string "result_desc"
    t.string "checkout_key"
    t.text "raw_callback"
    t.index ["checkout_key"], name: "index_payments_on_checkout_key", unique: true
    t.index ["mpesa_checkout_request_id"], name: "index_payments_on_mpesa_checkout_request_id"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "plan_metrics", force: :cascade do |t|
    t.string "plan_id", null: false
    t.date "metric_date", null: false
    t.float "plan_score", default: 0.0, null: false
    t.float "p95_latency_ms", default: 0.0, null: false
    t.float "cache_hit_rate", default: 0.0, null: false
    t.float "empty_section_rate", default: 0.0, null: false
    t.integer "requests", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "est_cost_usd", precision: 12, scale: 4, default: "0.0", null: false
    t.integer "errors", default: 0, null: false
    t.jsonb "metadata", default: {}, null: false
    t.index ["metadata"], name: "index_plan_metrics_on_metadata", using: :gin
    t.index ["metric_date", "plan_score"], name: "idx_plan_metrics_date_score"
    t.index ["plan_id", "metric_date"], name: "index_plan_metrics_on_plan_id_and_metric_date", unique: true
    t.check_constraint "cache_hit_rate >= 0::double precision AND cache_hit_rate <= 1::double precision", name: "chk_plan_metrics_cache_hit_rate"
    t.check_constraint "empty_section_rate >= 0::double precision AND empty_section_rate <= 1::double precision", name: "chk_plan_metrics_empty_section_rate"
    t.check_constraint "errors >= 0", name: "chk_plan_metrics_errors_positive"
    t.check_constraint "est_cost_usd >= 0::numeric", name: "chk_plan_metrics_cost_positive"
    t.check_constraint "p95_latency_ms >= 0::double precision", name: "chk_plan_metrics_latency_positive"
    t.check_constraint "requests >= 0", name: "chk_plan_metrics_requests_positive"
  end

  create_table "playbooks", force: :cascade do |t|
    t.string "playbook_id", null: false
    t.bigint "user_id"
    t.string "cohort_id"
    t.string "page", null: false
    t.integer "valid_for_hours", default: 48, null: false
    t.datetime "generated_at", null: false
    t.boolean "ai_generated", default: true, null: false
    t.json "content", null: false
    t.json "user_context"
    t.json "ai_instructions"
    t.string "ai_model_version"
    t.string "ai_prompt_version"
    t.decimal "generation_cost_usd", precision: 10, scale: 4
    t.integer "generation_duration_ms"
    t.text "generation_log"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_generated", "generated_at"], name: "idx_playbooks_ai_generated_time"
    t.index ["cohort_id", "page", "generated_at"], name: "idx_playbooks_cohort_page_time"
    t.index ["cohort_id"], name: "index_playbooks_on_cohort_id"
    t.index ["generated_at"], name: "index_playbooks_on_generated_at"
    t.index ["page", "generated_at"], name: "idx_playbooks_page_time"
    t.index ["page"], name: "index_playbooks_on_page"
    t.index ["playbook_id"], name: "index_playbooks_on_playbook_id", unique: true
    t.index ["user_id", "page", "generated_at"], name: "idx_playbooks_user_page_time"
    t.index ["user_id"], name: "index_playbooks_on_user_id"
  end

  create_table "product_relation_overrides", force: :cascade do |t|
    t.bigint "seed_id", null: false
    t.bigint "cand_id", null: false
    t.text "action", null: false
    t.float "weight", default: 0.2
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["seed_id", "cand_id"], name: "index_product_relation_overrides_on_seed_id_and_cand_id", unique: true
  end

  create_table "product_relations", primary_key: ["seed_id", "cand_id", "rel_type", "region"], force: :cascade do |t|
    t.bigserial "id", null: false
    t.bigint "seed_id", null: false
    t.bigint "cand_id", null: false
    t.text "rel_type", null: false
    t.float "score", null: false
    t.jsonb "features", default: {}
    t.text "region", null: false
    t.timestamptz "updated_at", null: false
    t.index ["cand_id", "rel_type", "region"], name: "index_product_relations_on_cand_id_and_rel_type_and_region"
    t.index ["region", "rel_type", "score"], name: "index_product_relations_on_region_and_rel_type_and_score"
    t.index ["seed_id", "rel_type", "region"], name: "index_product_relations_on_seed_id_and_rel_type_and_region"
  end

  create_table "product_relationships", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "related_product_id", null: false
    t.string "relationship_type", null: false
    t.float "strength_score", default: 0.0
    t.jsonb "context", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["context"], name: "index_product_relationships_on_context", using: :gin
    t.index ["product_id", "related_product_id", "relationship_type"], name: "idx_product_relationships_unique", unique: true
    t.index ["product_id", "relationship_type"], name: "idx_on_product_id_relationship_type_46b6d10481"
    t.index ["product_id"], name: "index_product_relationships_on_product_id"
    t.index ["related_product_id", "relationship_type"], name: "idx_on_related_product_id_relationship_type_e9b9b4235a"
    t.index ["related_product_id"], name: "index_product_relationships_on_related_product_id"
    t.index ["strength_score"], name: "index_product_relationships_on_strength_score"
  end

  create_table "product_variants", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "sku"
    t.string "size"
    t.string "color"
    t.integer "stock", default: 0, null: false
    t.decimal "price_override", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "size", "color"], name: "index_product_variants_on_product_id_and_size_and_color", unique: true
    t.index ["product_id"], name: "index_product_variants_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.string "main_image"
    t.decimal "price"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "views"
    t.bigint "shop_id", null: false
    t.jsonb "supplementary_images"
    t.bigint "category_id"
    t.string "color"
    t.string "size"
    t.integer "stock"
    t.string "moderation_label"
    t.float "moderation_confidence"
    t.datetime "last_indexed_at"
    t.text "moderation_reason"
    t.string "moderation_status", default: "pending"
    t.boolean "pickup_ready"
    t.bigint "brand_id"
    t.string "vector_id"
    t.string "subcategory"
    t.string "material"
    t.string "style"
    t.string "use_case"
    t.jsonb "specifications", default: {}
    t.string "seasonality"
    t.jsonb "schema_attributes", default: {}
    t.string "schema_version"
    t.string "status", default: "draft"
    t.index "to_tsvector('english'::regconfig, (((((((COALESCE(name, ''::character varying))::text || ' '::text) || COALESCE(description, ''::text)) || ' '::text) || (COALESCE(color, ''::character varying))::text) || ' '::text) || (COALESCE(size, ''::character varying))::text))", name: "idx_products_bm25_search", using: :gin
    t.index ["brand_id"], name: "index_products_on_brand_id"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["description"], name: "idx_products_description_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["material"], name: "index_products_on_material"
    t.index ["moderation_status", "stock", "pickup_ready"], name: "idx_products_search_composite", where: "(((moderation_status)::text = 'approved'::text) AND (stock > 0))"
    t.index ["name"], name: "idx_products_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["schema_attributes"], name: "index_products_on_schema_attributes", using: :gin
    t.index ["schema_version"], name: "index_products_on_schema_version"
    t.index ["seasonality"], name: "index_products_on_seasonality"
    t.index ["shop_id"], name: "index_products_on_shop_id"
    t.index ["specifications"], name: "index_products_on_specifications", using: :gin
    t.index ["status", "schema_version"], name: "index_products_on_status_and_schema_version"
    t.index ["status"], name: "index_products_on_status"
    t.index ["style"], name: "index_products_on_style"
    t.index ["subcategory"], name: "index_products_on_subcategory"
    t.index ["use_case"], name: "index_products_on_use_case"
  end

  create_table "recommended_products", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.integer "rank", default: 0
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_recommended_products_on_product_id"
    t.index ["user_id", "product_id"], name: "index_recommended_products_on_user_id_and_product_id", unique: true
    t.index ["user_id"], name: "index_recommended_products_on_user_id"
  end

  create_table "schemas", id: :string, force: :cascade do |t|
    t.string "category", null: false
    t.jsonb "schema_json", null: false
    t.string "version", null: false
    t.boolean "active", default: true
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_schemas_on_active"
    t.index ["category"], name: "index_schemas_on_category"
    t.index ["schema_json"], name: "index_schemas_on_schema_json", using: :gin
  end

  create_table "shops", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone"
    t.string "location"
    t.string "pickup_agent"
    t.boolean "agreed"
    t.string "store_logo_url"
    t.decimal "lat"
    t.decimal "lon"
    t.string "geohash6"
    t.index ["user_id"], name: "index_shops_on_user_id"
  end

  create_table "similar_products", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "similar_product_id", null: false
    t.float "score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_similar_products_on_product_id"
  end

  create_table "usecase_templates", force: :cascade do |t|
    t.text "template_id", null: false
    t.text "name", null: false
    t.jsonb "slots", default: []
    t.jsonb "rules", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["template_id"], name: "index_usecase_templates_on_template_id", unique: true
  end

  create_table "user_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "version", default: "up_v1", null: false
    t.jsonb "data", default: {}, null: false
    t.datetime "computed_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["computed_at"], name: "idx_user_profiles_computed_at"
    t.index ["user_id", "version"], name: "index_user_profiles_on_user_id_and_version", unique: true
    t.index ["user_id"], name: "index_user_profiles_on_user_id"
    t.check_constraint "version::text = ANY (ARRAY['up_v1'::character varying::text, 'up_v2'::character varying::text])", name: "chk_user_profiles_version"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "google_id"
    t.string "avatar"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "role", default: 0, null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "wishlist_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_wishlist_items_on_product_id"
    t.index ["user_id", "product_id"], name: "index_wishlist_items_on_user_id_and_product_id", unique: true
    t.index ["user_id"], name: "index_wishlist_items_on_user_id"
  end

  create_table "withdrawal_requests", force: :cascade do |t|
    t.bigint "merchant_wallet_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "status", default: "requested", null: false
    t.string "mpesa_conversation_id"
    t.string "mpesa_receipt_number"
    t.string "phone_number"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["merchant_wallet_id"], name: "index_withdrawal_requests_on_merchant_wallet_id"
  end

  add_foreign_key "cart_items", "products"
  add_foreign_key "cart_items", "users"
  add_foreign_key "complementary_products", "products"
  add_foreign_key "complementary_products", "products", column: "complementary_product_id"
  add_foreign_key "delivery_addresses", "users"
  add_foreign_key "events", "users"
  add_foreign_key "experiment_assignments", "experiments"
  add_foreign_key "feed_exposures", "feeds"
  add_foreign_key "feed_exposures", "products"
  add_foreign_key "feed_items", "feeds", on_delete: :cascade
  add_foreign_key "feed_items", "products"
  add_foreign_key "feeds", "users", on_delete: :nullify
  add_foreign_key "merchant_payments", "orders"
  add_foreign_key "merchant_payments", "payments"
  add_foreign_key "merchant_payments", "shops"
  add_foreign_key "merchant_wallets", "shops"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "delivery_addresses"
  add_foreign_key "orders", "payments"
  add_foreign_key "orders", "shops"
  add_foreign_key "orders", "users"
  add_foreign_key "payments", "users"
  add_foreign_key "playbooks", "users"
end
