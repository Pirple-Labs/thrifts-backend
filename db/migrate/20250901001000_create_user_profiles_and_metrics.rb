class CreateUserProfilesAndMetrics < ActiveRecord::Migration[7.0]
  def change
    create_table :user_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :version, null: false, default: "up_v1"
      t.jsonb   :data, null: false, default: {}
      t.datetime :computed_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.timestamps
    end
    add_index :user_profiles, [:user_id, :version], unique: true

    create_table :exposure_outcomes do |t|
      t.string  :feed_uid, null: false
      t.string  :plan_id, null: false
      t.string  :section, null: false
      t.bigint  :product_id, null: false
      t.integer :position, null: false
      t.boolean :clicked_5m, default: false, null: false
      t.boolean :atc_30m, default: false, null: false
      t.boolean :purchased_24h, default: false, null: false
      t.float   :item_weight_w1, default: 0.0, null: false
      t.datetime :window_start, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :window_end, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.timestamps
    end
    add_index :exposure_outcomes, [:feed_uid, :plan_id, :section, :product_id, :position], name: "idx_exposure_tuple"

    create_table :plan_metrics do |t|
      t.string  :plan_id, null: false
      t.date    :metric_date, null: false
      t.float   :plan_score, default: 0.0, null: false
      t.float   :p95_latency_ms, default: 0.0, null: false
      t.float   :cache_hit_rate, default: 0.0, null: false
      t.float   :empty_section_rate, default: 0.0, null: false
      t.integer :requests, default: 0, null: false
      t.timestamps
    end
    add_index :plan_metrics, [:plan_id, :metric_date], unique: true
  end
end


