class AddBm25SearchIndexes < ActiveRecord::Migration[7.0]
  def up
    # Enable pg_trgm extension for fuzzy matching (if not already enabled)
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')
    
    # Create composite tsvector index for BM25 search
    # This combines name, description, tags, and category for full-text search
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS idx_products_bm25_search 
      ON products 
      USING gin(
        to_tsvector('english', 
          COALESCE(name, '') || ' ' || 
          COALESCE(description, '') || ' ' || 
          COALESCE(color, '') || ' ' || 
          COALESCE(size, '')
        )
      );
    SQL
    
    # Create trigram indexes for fuzzy matching on name and description
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS idx_products_name_trgm 
      ON products USING gin(name gin_trgm_ops);
    SQL
    
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS idx_products_description_trgm 
      ON products USING gin(description gin_trgm_ops);
    SQL
    
    # Create composite index for search performance
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS idx_products_search_composite 
      ON products (moderation_status, stock, pickup_ready) 
      WHERE moderation_status = 'approved' AND stock > 0;
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX IF EXISTS idx_products_bm25_search;
      DROP INDEX IF EXISTS idx_products_name_trgm;
      DROP INDEX IF EXISTS idx_products_description_trgm;
      DROP INDEX IF EXISTS idx_products_search_composite;
    SQL
  end
end
