class CreateProductRelationOverrides < ActiveRecord::Migration[8.0]
  def change
    create_table :product_relation_overrides do |t|
      t.bigint :seed_id, null: false
      t.bigint :cand_id, null: false
      t.text :action, null: false # 'boost'|'block'
      t.float :weight, default: 0.2 # additive to score
      t.text :note
      t.timestamps
    end
    
    add_index :product_relation_overrides, [:seed_id, :cand_id], unique: true
    add_foreign_key :product_relation_overrides, :products, column: :seed_id
    add_foreign_key :product_relation_overrides, :products, column: :cand_id
  end
end
