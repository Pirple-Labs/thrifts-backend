class AddExperimentationAndUsageTracking < ActiveRecord::Migration[7.0]
  def change
    # 1. Experiments catalog
    create_table :experiments do |t|
      t.string :key, null: false  # e.g. 'home_ranker_ab_2025q3'
      t.string :status, null: false, default: 'draft'
      t.integer :traffic_pct, null: false, default: 50
      t.timestamps
    end
    
    # Add unique constraint on key column
    add_index :experiments, :key, unique: true, name: "idx_experiments_key_unique"
    
    add_check_constraint :experiments, "status IN ('draft','running','paused','complete')", name: "check_experiments_status"
    add_check_constraint :experiments, "traffic_pct BETWEEN 0 AND 100", name: "check_experiments_traffic_pct"
    
    # 2. Experiment assignments by user or session
    create_table :experiment_assignments do |t|
      t.references :experiment, null: false, foreign_key: true
      t.bigint :user_id, null: true
      t.string :session_id, null: true
      t.string :variant, null: false
      t.timestamp :assigned_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.timestamps
    end
    
    add_check_constraint :experiment_assignments, "variant IN ('control','operator')", name: "check_assignments_variant"
    add_index :experiment_assignments, [:experiment_id, :user_id], unique: true, where: "user_id IS NOT NULL"
    add_index :experiment_assignments, [:experiment_id, :session_id], unique: true, where: "session_id IS NOT NULL"
    
    # 3. API usage tracking (daily buckets)
    create_table :api_usage do |t|
      t.string :plan_id, null: false
      t.string :endpoint, null: false  # '/api/feeds/start', '/api/feeds/next', '/api/events'
      t.date :ts, null: false  # daily bucket
      t.integer :calls, null: false, default: 0
      t.decimal :gpu_seconds, precision: 12, scale: 3, null: false, default: 0
      t.decimal :cpu_seconds, precision: 12, scale: 3, null: false, default: 0
      t.integer :tokens, null: false, default: 0  # for LLM/operator
      t.decimal :est_cost_usd, precision: 12, scale: 4, null: false, default: 0
      t.timestamps
    end
    
    add_index :api_usage, [:plan_id, :endpoint, :ts], unique: true, name: "idx_api_usage_unique"
    
    # 4. Add experiment fields to feeds table
    add_column :feeds, :experiment_key, :string
    add_column :feeds, :variant, :string
    add_check_constraint :feeds, "variant IN ('control','operator')", name: "check_feeds_variant"
    add_index :feeds, [:experiment_key, :variant], name: "idx_feeds_experiment"
    
    # 5. Add cost and error tracking to plan_metrics
    add_column :plan_metrics, :est_cost_usd, :decimal, precision: 12, scale: 4, null: false, default: 0
    add_column :plan_metrics, :errors, :integer, null: false, default: 0
    
    # 6. Seed initial experiment - use INSERT with proper conflict handling
    execute <<-SQL
      INSERT INTO experiments (key, status, traffic_pct, created_at, updated_at)
      VALUES ('home_ranker_ab_2025q3', 'draft', 10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT (key) DO NOTHING;
    SQL
  end
end
