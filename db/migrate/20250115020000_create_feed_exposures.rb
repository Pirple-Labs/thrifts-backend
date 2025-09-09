# frozen_string_literal: true

class CreateFeedExposures < ActiveRecord::Migration[8.0]
  def change
    create_table :feed_exposures do |t|
      t.references :feed, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :section_id, null: false
      t.integer :position, null: false
      t.string :profile_hash, null: false
      t.string :reason_hash, null: false
      t.jsonb :pre_guard_candidates, default: {}
      t.jsonb :guardrail_drops, default: {}
      t.float :propensity, null: false, default: 1.0
      t.integer :latency_ms_retrieval, null: false, default: 0
      t.integer :latency_ms_guardrails, null: false, default: 0
      t.integer :latency_ms_coord, null: false, default: 0
      t.integer :latency_ms_total, null: false, default: 0
      
      t.timestamps
    end
    
    # Indexes for efficient querying
    add_index :feed_exposures, [:feed_id, :section_id, :position]
    add_index :feed_exposures, [:section_id, :position]
    add_index :feed_exposures, :profile_hash
    add_index :feed_exposures, :reason_hash
    add_index :feed_exposures, :propensity
    add_index :feed_exposures, :latency_ms_total
    add_index :feed_exposures, :pre_guard_candidates, using: :gin
    add_index :feed_exposures, :guardrail_drops, using: :gin
    
    # Composite index for plan analysis
    add_index :feed_exposures, [:feed_id, :section_id], name: 'idx_feed_exposures_feed_section'
  end
end

