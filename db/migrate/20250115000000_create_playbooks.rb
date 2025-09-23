# db/migrate/20250115000000_create_playbooks.rb
# frozen_string_literal: true

class CreatePlaybooks < ActiveRecord::Migration[7.0]
  def change
    create_table :playbooks do |t|
      t.string :playbook_id, null: false, index: { unique: true }
      t.references :user, null: true, foreign_key: true
      t.string :cohort_id, null: true, index: true
      t.string :page, null: false, index: true
      t.integer :valid_for_hours, null: false, default: 48
      t.datetime :generated_at, null: false, index: true
      t.boolean :ai_generated, null: false, default: true
      t.json :content, null: false
      t.json :user_context, null: true
      t.json :ai_instructions, null: true
      t.string :ai_model_version, null: true
      t.string :ai_prompt_version, null: true
      t.decimal :generation_cost_usd, precision: 10, scale: 4, null: true
      t.integer :generation_duration_ms, null: true
      t.text :generation_log, null: true
      
      t.timestamps
    end
    
    add_index :playbooks, [:user_id, :page, :generated_at], name: 'idx_playbooks_user_page_time'
    add_index :playbooks, [:cohort_id, :page, :generated_at], name: 'idx_playbooks_cohort_page_time'
    add_index :playbooks, [:page, :generated_at], name: 'idx_playbooks_page_time'
    add_index :playbooks, [:ai_generated, :generated_at], name: 'idx_playbooks_ai_generated_time'
  end
end

