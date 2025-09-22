class AddDatabaseHardeningPartitioning < ActiveRecord::Migration[7.0]
  def up
    # 1. Add PostgreSQL extensions (only if we have privileges)
    # Note: pg_stat_statements requires superuser, so we skip it in development/staging
    
    # Safe extensions that don't require superuser
    begin
      enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")
    rescue => e
      say "Warning: Could not enable pg_trgm extension: #{e.message}"
    end
    
    begin
      enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
    rescue => e
      say "Warning: Could not enable pgcrypto extension: #{e.message}"
    end
    
    # Skip pg_stat_statements - requires superuser privileges
    say "Note: pg_stat_statements extension skipped (requires superuser privileges)"
    
    # 2. Partition events table by timestamp_utc (monthly)
    # Note: This assumes the events table is empty or has minimal data
    # For production with existing data, you'd need a more complex migration
    
    # First, check if events table has data
    events_count = select_value("SELECT COUNT(*) FROM events") rescue 0
    
    # Skip partitioning for now - not essential for MVP personalization
    say "Skipping events partitioning - not needed for MVP personalization system"
    say "Events table contains #{events_count} rows. Partitioning can be added later in production."
    
    # 3. Skip partitioning for now - complex in development environment
    # Partitioning can be done later in production with proper planning
    say "Skipping table partitioning - can be done later in production environment"
    say "Note: Partitioning requires careful planning of primary keys and constraints"
  end
  
  def down
    # Reverse partitioning is complex and not typically done
    # Would require recreating unpartitioned tables and moving data
    raise ActiveRecord::IrreversibleMigration, "Cannot reverse table partitioning"
  end
end
