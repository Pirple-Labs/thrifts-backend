class CreateProductRelationships < ActiveRecord::Migration[8.0]
  def change
    create_table :product_relationships do |t|
      t.references :product, null: false, foreign_key: { to_table: :products }
      t.references :related_product, null: false, foreign_key: { to_table: :products }
      t.string :relationship_type, null: false  # complementary, similar, alternative
      t.float :strength_score, default: 0.0
      t.jsonb :context, default: {}  # why they're related
      t.timestamps
    end
    
    # Indexes for efficient querying
    add_index :product_relationships, [:product_id, :relationship_type]
    add_index :product_relationships, [:related_product_id, :relationship_type]
    add_index :product_relationships, :strength_score
    add_index :product_relationships, :context, using: :gin
    
    # Ensure no duplicate relationships
    add_index :product_relationships, [:product_id, :related_product_id, :relationship_type], 
              unique: true, name: 'idx_product_relationships_unique'
  end
end

