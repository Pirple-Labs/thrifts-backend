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
    
    if events_count.to_i == 0
      # Safe to partition empty table
      execute <<-SQL
        -- Convert events to partitioned table
        CREATE TABLE events_new (LIKE events INCLUDING ALL) PARTITION BY RANGE (timestamp_utc);
        
        -- Create current and next 2 months partitions
        CREATE TABLE events_#{Date.current.strftime('%Y_%m')} PARTITION OF events_new
          FOR VALUES FROM ('#{Date.current.beginning_of_month}') TO ('#{1.month.from_now.beginning_of_month}');
        
        CREATE TABLE events_#{1.month.from_now.strftime('%Y_%m')} PARTITION OF events_new
          FOR VALUES FROM ('#{1.month.from_now.beginning_of_month}') TO ('#{2.months.from_now.beginning_of_month}');
        
        CREATE TABLE events_#{2.months.from_now.strftime('%Y_%m')} PARTITION OF events_new
          FOR VALUES FROM ('#{2.months.from_now.beginning_of_month}') TO ('#{3.months.from_now.beginning_of_month}');
        
        -- Recreate indexes on partitions
        CREATE UNIQUE INDEX idx_events_#{Date.current.strftime('%Y_%m')}_event_id 
          ON events_#{Date.current.strftime('%Y_%m')}(event_id);
        CREATE INDEX idx_events_#{Date.current.strftime('%Y_%m')}_user_session_time 
          ON events_#{Date.current.strftime('%Y_%m')}(user_id, session_id, timestamp_utc);
        CREATE INDEX idx_events_#{Date.current.strftime('%Y_%m')}_name_time 
          ON events_#{Date.current.strftime('%Y_%m')}(event_name, timestamp_utc);
        CREATE INDEX idx_events_#{Date.current.strftime('%Y_%m')}_payload_gin 
          ON events_#{Date.current.strftime('%Y_%m')} USING gin(payload);
        
        -- Repeat indexes for next month partitions
        CREATE UNIQUE INDEX idx_events_#{1.month.from_now.strftime('%Y_%m')}_event_id 
          ON events_#{1.month.from_now.strftime('%Y_%m')}(event_id);
        CREATE INDEX idx_events_#{1.month.from_now.strftime('%Y_%m')}_user_session_time 
          ON events_#{1.month.from_now.strftime('%Y_%m')}(user_id, session_id, timestamp_utc);
        CREATE INDEX idx_events_#{1.month.from_now.strftime('%Y_%m')}_name_time 
          ON events_#{1.month.from_now.strftime('%Y_%m')}(event_name, timestamp_utc);
        CREATE INDEX idx_events_#{1.month.from_now.strftime('%Y_%m')}_payload_gin 
          ON events_#{1.month.from_now.strftime('%Y_%m')} USING gin(payload);
        
        CREATE UNIQUE INDEX idx_events_#{2.months.from_now.strftime('%Y_%m')}_event_id 
          ON events_#{2.months.from_now.strftime('%Y_%m')}(event_id);
        CREATE INDEX idx_events_#{2.months.from_now.strftime('%Y_%m')}_user_session_time 
          ON events_#{2.months.from_now.strftime('%Y_%m')}(user_id, session_id, timestamp_utc);
        CREATE INDEX idx_events_#{2.months.from_now.strftime('%Y_%m')}_name_time 
          ON events_#{2.months.from_now.strftime('%Y_%m')}(event_name, timestamp_utc);
        CREATE INDEX idx_events_#{2.months.from_now.strftime('%Y_%m')}_payload_gin 
          ON events_#{2.months.from_now.strftime('%Y_%m')} USING gin(payload);
        
        -- Replace original table
        DROP TABLE events;
        ALTER TABLE events_new RENAME TO events;
      SQL
    else
      # Skip partitioning if data exists - would need manual intervention
      say "Events table contains #{events_count} rows. Skipping partitioning - manual intervention required."
    end
    
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
