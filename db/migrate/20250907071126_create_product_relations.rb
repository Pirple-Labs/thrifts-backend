class CreateProductRelations < ActiveRecord::Migration[8.0]
  def change
    create_table :product_relations do |t|
      t.bigint :seed_id, null: false
      t.bigint :cand_id, null: false
      t.text :rel_type, null: false # 'complement'|'similar'
      t.float :score, null: false
      t.jsonb :features, default: {} # {cp:..., cv:..., emb:..., attr_harmony:...}
      t.text :region, null: false
      t.timestamptz :updated_at, null: false
    end
    
    add_index :product_relations, [:seed_id, :rel_type, :region]
    add_index :product_relations, [:cand_id, :rel_type, :region]
    add_index :product_relations, [:region, :rel_type, :score]
    add_foreign_key :product_relations, :products, column: :seed_id
    add_foreign_key :product_relations, :products, column: :cand_id
    
    # Composite primary key
    execute "ALTER TABLE product_relations DROP CONSTRAINT product_relations_pkey"
    execute "ALTER TABLE product_relations ADD PRIMARY KEY (seed_id, cand_id, rel_type, region)"
  end
end
