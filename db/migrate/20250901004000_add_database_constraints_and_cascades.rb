class AddDatabaseConstraintsAndCascades < ActiveRecord::Migration[7.0]
  def up
    # 1. Add FK cascade for feed_items -> feeds (auto-cleanup)
    remove_foreign_key :feed_items, :feeds if foreign_key_exists?(:feed_items, :feeds)
    add_foreign_key :feed_items, :feeds, on_delete: :cascade
    
    # 2. Add CHECK constraints for data quality
    
    # Feeds constraints
    add_check_constraint :feeds, "page IN ('home','pdp','profile','cart','checkout')", 
                        name: "chk_feeds_page"
    add_check_constraint :feeds, "is_cache_hit IN (TRUE,FALSE)", 
                        name: "chk_feeds_is_cache_hit"
    add_check_constraint :feeds, "ttl_seconds > 0", 
                        name: "chk_feeds_ttl_positive"
    
    # Feed items constraints  
    add_check_constraint :feed_items, "section IN ('grid','trending','search_results','recommendations')", 
                        name: "chk_feed_items_section"
    add_check_constraint :feed_items, "role IN ('search','trending','similar','image_search','recommendation','fallback')", 
                        name: "chk_feed_items_role"
    add_check_constraint :feed_items, "position >= 0", 
                        name: "chk_feed_items_position_positive"
    add_check_constraint :feed_items, "vec_score >= 0 AND vec_score <= 1", 
                        name: "chk_feed_items_vec_score_range"
    
    # Plan metrics constraints
    add_check_constraint :plan_metrics, "cache_hit_rate >= 0 AND cache_hit_rate <= 1", 
                        name: "chk_plan_metrics_cache_hit_rate"
    add_check_constraint :plan_metrics, "empty_section_rate >= 0 AND empty_section_rate <= 1", 
                        name: "chk_plan_metrics_empty_section_rate"
    add_check_constraint :plan_metrics, "p95_latency_ms >= 0", 
                        name: "chk_plan_metrics_latency_positive"
    add_check_constraint :plan_metrics, "requests >= 0", 
                        name: "chk_plan_metrics_requests_positive"
    add_check_constraint :plan_metrics, "errors >= 0", 
                        name: "chk_plan_metrics_errors_positive"
    add_check_constraint :plan_metrics, "est_cost_usd >= 0", 
                        name: "chk_plan_metrics_cost_positive"
    
    # API usage constraints
    add_check_constraint :api_usage, "calls >= 0", 
                        name: "chk_api_usage_calls_positive"
    add_check_constraint :api_usage, "gpu_seconds >= 0", 
                        name: "chk_api_usage_gpu_positive"
    add_check_constraint :api_usage, "cpu_seconds >= 0", 
                        name: "chk_api_usage_cpu_positive"
    add_check_constraint :api_usage, "tokens >= 0", 
                        name: "chk_api_usage_tokens_positive"
    add_check_constraint :api_usage, "est_cost_usd >= 0", 
                        name: "chk_api_usage_cost_positive"
    add_check_constraint :api_usage, "endpoint IN ('/api/feeds/start','/api/feeds/next','/api/events')", 
                        name: "chk_api_usage_endpoint"
    
    # Events constraints
    add_check_constraint :events, "page IN ('home','pdp','profile','cart','checkout','search')", 
                        name: "chk_events_page"
    add_check_constraint :events, "schema_version IN ('v1','v2')", 
                        name: "chk_events_schema_version"
    add_check_constraint :events, "timestamp_utc <= received_at + INTERVAL '10 minutes'", 
                        name: "chk_events_timestamp_reasonable"
    
    # User profiles constraints
    add_check_constraint :user_profiles, "version IN ('up_v1','up_v2')", 
                        name: "chk_user_profiles_version"
    
    # Product embeddings constraints (skip dimension check for now)
    # Note: vector dimensions are enforced by the vector type itself
    # add_check_constraint would require custom function for pgvector
    
    # 3. Add useful composite indexes for hot queries
    
    # Feed performance indexes
    add_index :feeds, [:user_id, :created_at], name: "idx_feeds_user_time"
    add_index :feeds, [:session_id, :created_at], name: "idx_feeds_session_time"
    add_index :feeds, [:plan_id, :created_at], name: "idx_feeds_plan_time"
    
    # Feed items performance indexes
    add_index :feed_items, [:product_id, :created_at], name: "idx_feed_items_product_time"
    add_index :feed_items, [:section, :position], name: "idx_feed_items_section_position"
    
    # Plan metrics indexes
    add_index :plan_metrics, [:metric_date, :plan_score], name: "idx_plan_metrics_date_score"
    
    # API usage indexes
    add_index :api_usage, [:ts, :plan_id], name: "idx_api_usage_date_plan"
    add_index :api_usage, [:endpoint, :ts], name: "idx_api_usage_endpoint_date"
    
    # User profiles indexes
    add_index :user_profiles, [:computed_at], name: "idx_user_profiles_computed_at"
    
    # Experiment assignment indexes
    add_index :experiment_assignments, [:user_id, :assigned_at], name: "idx_experiment_assignments_user_time"
    add_index :experiment_assignments, [:session_id, :assigned_at], name: "idx_experiment_assignments_session_time"
    add_index :experiment_assignments, [:variant, :assigned_at], name: "idx_experiment_assignments_variant_time"
  end
  
  def down
    # Remove check constraints
    remove_check_constraint :feeds, name: "chk_feeds_page"
    remove_check_constraint :feeds, name: "chk_feeds_is_cache_hit"
    remove_check_constraint :feeds, name: "chk_feeds_ttl_positive"
    
    remove_check_constraint :feed_items, name: "chk_feed_items_section"
    remove_check_constraint :feed_items, name: "chk_feed_items_role"
    remove_check_constraint :feed_items, name: "chk_feed_items_position_positive"
    remove_check_constraint :feed_items, name: "chk_feed_items_vec_score_range"
    
    remove_check_constraint :plan_metrics, name: "chk_plan_metrics_cache_hit_rate"
    remove_check_constraint :plan_metrics, name: "chk_plan_metrics_empty_section_rate"
    remove_check_constraint :plan_metrics, name: "chk_plan_metrics_latency_positive"
    remove_check_constraint :plan_metrics, name: "chk_plan_metrics_requests_positive"
    remove_check_constraint :plan_metrics, name: "chk_plan_metrics_errors_positive"
    remove_check_constraint :plan_metrics, name: "chk_plan_metrics_cost_positive"
    
    remove_check_constraint :api_usage, name: "chk_api_usage_calls_positive"
    remove_check_constraint :api_usage, name: "chk_api_usage_gpu_positive"
    remove_check_constraint :api_usage, name: "chk_api_usage_cpu_positive"
    remove_check_constraint :api_usage, name: "chk_api_usage_tokens_positive"
    remove_check_constraint :api_usage, name: "chk_api_usage_cost_positive"
    remove_check_constraint :api_usage, name: "chk_api_usage_endpoint"
    
    remove_check_constraint :events, name: "chk_events_page"
    remove_check_constraint :events, name: "chk_events_schema_version"
    remove_check_constraint :events, name: "chk_events_timestamp_reasonable"
    
    remove_check_constraint :user_profiles, name: "chk_user_profiles_version"
    remove_check_constraint :product_embeddings, name: "chk_product_embeddings_dimension"
    
    # Remove indexes
    remove_index :feeds, name: "idx_feeds_user_time"
    remove_index :feeds, name: "idx_feeds_session_time"
    remove_index :feeds, name: "idx_feeds_plan_time"
    
    remove_index :feed_items, name: "idx_feed_items_product_time"
    remove_index :feed_items, name: "idx_feed_items_section_position"
    
    remove_index :plan_metrics, name: "idx_plan_metrics_date_score"
    
    remove_index :api_usage, name: "idx_api_usage_date_plan"
    remove_index :api_usage, name: "idx_api_usage_endpoint_date"
    
    remove_index :user_profiles, name: "idx_user_profiles_computed_at"
    
    remove_index :experiment_assignments, name: "idx_experiment_assignments_user_time"
    remove_index :experiment_assignments, name: "idx_experiment_assignments_session_time"
    remove_index :experiment_assignments, name: "idx_experiment_assignments_variant_time"
    
    # Revert FK cascade
    remove_foreign_key :feed_items, :feeds
    add_foreign_key :feed_items, :feeds  # back to default (no cascade)
  end
end
