class CreateSearchImageCache < ActiveRecord::Migration[7.0]
  def change
    create_table :search_image_cache do |t|
      t.string :cache_key, null: false, index: { unique: true }
      t.string :public_id, null: false
      t.string :transform_params, null: false
      t.string :version, null: false, default: 'clip_v1'
      t.integer :hit_count, null: false, default: 0
      t.timestamp :last_accessed_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamps
    end
    
    # Add vector column using SQL (Rails doesn't have native vector support)
    execute "ALTER TABLE search_image_cache ADD COLUMN embedding vector(512)"
    
    # Indexes for performance
    add_index :search_image_cache, :public_id
    add_index :search_image_cache, [:version, :created_at]
    add_index :search_image_cache, :last_accessed_at
    
    # Vector similarity index
    execute "CREATE INDEX idx_search_image_cache_embedding_hnsw ON search_image_cache USING hnsw (embedding vector_cosine_ops)"
    
    # Cleanup old entries (optional)
    execute <<-SQL
      CREATE OR REPLACE FUNCTION cleanup_old_image_cache()
      RETURNS void AS $$
      BEGIN
        DELETE FROM search_image_cache 
        WHERE last_accessed_at < NOW() - INTERVAL '30 days'
          AND hit_count < 5;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end
  
  def down
    drop_table :search_image_cache
    execute "DROP FUNCTION IF EXISTS cleanup_old_image_cache();"
  end
end
