class EnablePgvectorAndCreateProductEmbeddings < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    enable_extension 'vector' unless extension_enabled?('vector')

    create_table :product_embeddings, if_not_exists: true do |t|
      t.references :product, null: false, foreign_key: true, index: false
      t.column :embedding, :vector, limit: 1536, null: false
      t.string :index_version, null: false, default: 'vec_2025_08_17'
      t.timestamp :embedded_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamps
    end

    # 🔧 Ensure the column has a fixed dimension (needed for ivfflat)
    execute "ALTER TABLE product_embeddings ALTER COLUMN embedding TYPE vector(1536);"

    unless index_exists?(:product_embeddings, :product_id, name: "index_product_embeddings_on_product_id")
      add_index :product_embeddings, :product_id,
                unique: true, algorithm: :concurrently,
                name: "index_product_embeddings_on_product_id"
    end

    unless index_exists?(:product_embeddings, :embedding, name: "index_product_embeddings_on_embedding_ivfflat")
      add_index :product_embeddings, :embedding,
                using: :ivfflat, opclass: :vector_cosine_ops,
                algorithm: :concurrently,
                name: "index_product_embeddings_on_embedding_ivfflat"
    end
  end

  def down
    execute "DROP INDEX CONCURRENTLY IF EXISTS index_product_embeddings_on_embedding_ivfflat"
    execute "DROP INDEX CONCURRENTLY IF EXISTS index_product_embeddings_on_product_id"
    drop_table :product_embeddings, if_exists: true
  end
end
