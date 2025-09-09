class AddMetadataToPlanMetrics < ActiveRecord::Migration[7.0]
  def change
    add_column :plan_metrics, :metadata, :jsonb, default: {}, null: false
    
    # Add GIN index for metadata queries
    add_index :plan_metrics, :metadata, using: :gin
  end
end
