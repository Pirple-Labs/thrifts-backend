class PartitionRotationJob < ApplicationJob
  queue_as :default
  
  def perform
    Rails.logger.info "[PartitionRotationJob] Starting partition rotation"
    
    # Create next month's partitions if they don't exist
    create_next_month_partitions
    
    # Clean up old partitions based on retention policy
    cleanup_old_partitions
    
    Rails.logger.info "[PartitionRotationJob] Partition rotation completed"
  end
  
  private
  
  def create_next_month_partitions
    # Create partitions for next 3 months to ensure we never run out
    (1..3).each do |months_ahead|
      target_date = months_ahead.months.from_now
      partition_name = target_date.strftime('%Y_%m')
      start_date = target_date.beginning_of_month
      end_date = (months_ahead + 1).months.from_now.beginning_of_month
      
      # Events partitions
      create_events_partition(partition_name, start_date, end_date)
      
      # Exposure outcomes partitions  
      create_exposure_outcomes_partition(partition_name, start_date, end_date)
    end
  end
  
  def create_events_partition(partition_name, start_date, end_date)
    table_name = "events_#{partition_name}"
    
    # Check if partition already exists
    exists = ActiveRecord::Base.connection.select_value(<<-SQL)
      SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = '#{table_name}'
      );
    SQL
    
    return if exists
    
    Rails.logger.info "[PartitionRotationJob] Creating events partition: #{table_name}"
    
    ActiveRecord::Base.connection.execute(<<-SQL)
      CREATE TABLE #{table_name} PARTITION OF events
        FOR VALUES FROM ('#{start_date.iso8601}') TO ('#{end_date.iso8601}');
      
      -- Create indexes on the new partition
      CREATE UNIQUE INDEX idx_#{table_name}_event_id 
        ON #{table_name}(event_id);
      CREATE INDEX idx_#{table_name}_user_session_time 
        ON #{table_name}(user_id, session_id, timestamp_utc);
      CREATE INDEX idx_#{table_name}_name_time 
        ON #{table_name}(event_name, timestamp_utc);
      CREATE INDEX idx_#{table_name}_payload_gin 
        ON #{table_name} USING gin(payload);
      
      -- Hot window partial index for recent events
      CREATE INDEX idx_#{table_name}_name_time_hot
        ON #{table_name} (event_name, timestamp_utc)
        WHERE timestamp_utc > NOW() - INTERVAL '14 days';
    SQL
  end
  
  def create_exposure_outcomes_partition(partition_name, start_date, end_date)
    table_name = "exposure_outcomes_#{partition_name}"
    
    # Check if partition already exists
    exists = ActiveRecord::Base.connection.select_value(<<-SQL)
      SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = '#{table_name}'
      );
    SQL
    
    return if exists
    
    Rails.logger.info "[PartitionRotationJob] Creating exposure_outcomes partition: #{table_name}"
    
    ActiveRecord::Base.connection.execute(<<-SQL)
      CREATE TABLE #{table_name} PARTITION OF exposure_outcomes
        FOR VALUES FROM ('#{start_date.iso8601}') TO ('#{end_date.iso8601}');
      
      -- Create indexes on the new partition
      CREATE INDEX idx_exposure_#{partition_name}_tuple 
        ON #{table_name}(feed_uid, plan_id, section, product_id, position);
      CREATE INDEX idx_exposure_#{partition_name}_plan_date 
        ON #{table_name}(plan_id, DATE(window_start));
    SQL
  end
  
  def cleanup_old_partitions
    # Clean up events partitions older than 12 months
    cleanup_events_partitions
    
    # Clean up exposure outcomes partitions older than 12 months  
    cleanup_exposure_outcomes_partitions
    
    # Clean up feeds older than 30 days (cascade deletes feed_items)
    cleanup_feeds
  end
  
  def cleanup_events_partitions
    cutoff_date = 12.months.ago
    old_partitions = get_old_partitions('events', cutoff_date)
    
    old_partitions.each do |partition_name|
      Rails.logger.info "[PartitionRotationJob] Dropping old events partition: #{partition_name}"
      
      # Optional: Archive to cold storage before dropping
      # archive_partition_to_cold_storage(partition_name)
      
      ActiveRecord::Base.connection.execute(<<-SQL)
        DROP TABLE IF EXISTS #{partition_name} CASCADE;
      SQL
    end
  end
  
  def cleanup_exposure_outcomes_partitions
    cutoff_date = 12.months.ago
    old_partitions = get_old_partitions('exposure_outcomes', cutoff_date)
    
    old_partitions.each do |partition_name|
      Rails.logger.info "[PartitionRotationJob] Dropping old exposure_outcomes partition: #{partition_name}"
      
      ActiveRecord::Base.connection.execute(<<-SQL)
        DROP TABLE IF EXISTS #{partition_name} CASCADE;
      SQL
    end
  end
  
  def cleanup_feeds
    cutoff_date = 30.days.ago
    
    Rails.logger.info "[PartitionRotationJob] Cleaning up feeds older than #{cutoff_date}"
    
    # This will cascade delete feed_items due to FK constraint
    deleted_count = Feed.where('created_at < ?', cutoff_date).delete_all
    
    Rails.logger.info "[PartitionRotationJob] Deleted #{deleted_count} old feeds"
  end
  
  def get_old_partitions(base_table, cutoff_date)
    # Get partition names older than cutoff date
    ActiveRecord::Base.connection.select_values(<<-SQL)
      SELECT schemaname||'.'||tablename as full_name
      FROM pg_tables 
      WHERE tablename LIKE '#{base_table}_%'
        AND tablename ~ '^#{base_table}_[0-9]{4}_[0-9]{2}$'
        AND EXTRACT(YEAR FROM TO_DATE(SUBSTRING(tablename FROM '#{base_table}_(.*)'), 'YYYY_MM')) < #{cutoff_date.year}
        OR (
          EXTRACT(YEAR FROM TO_DATE(SUBSTRING(tablename FROM '#{base_table}_(.*)'), 'YYYY_MM')) = #{cutoff_date.year}
          AND EXTRACT(MONTH FROM TO_DATE(SUBSTRING(tablename FROM '#{base_table}_(.*)'), 'YYYY_MM')) < #{cutoff_date.month}
        );
    SQL
  end
  
  # Optional: Archive partition to cold storage before dropping
  def archive_partition_to_cold_storage(partition_name)
    # Implementation would depend on your cold storage solution
    # Examples: 
    # - COPY to S3 via pg_dump
    # - Export to Parquet files
    # - Move to data warehouse
    Rails.logger.info "[PartitionRotationJob] TODO: Archive #{partition_name} to cold storage"
  end
end
