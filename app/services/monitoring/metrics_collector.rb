module Monitoring
  class MetricsCollector
    class << self
      def collect_database_metrics
        {
          database: collect_pg_stats,
          replication: collect_replication_lag,
          cache_hit_ratio: collect_cache_hit_ratio,
          table_stats: collect_table_stats,
          query_performance: collect_slow_queries,
          timestamp: Time.current.iso8601
        }
      end
      
      def collect_business_metrics(days = 7)
        {
          experiments: collect_experiment_metrics(days),
          costs: collect_cost_metrics(days),
          performance: collect_performance_metrics(days),
          timestamp: Time.current.iso8601
        }
      end
      
      def collect_experiment_metrics(days = 7)
        cutoff = days.days.ago
        
        # CTR by experiment variant
        ctr_data = ActiveRecord::Base.connection.select_all(<<-SQL)
          WITH impressions AS (
            SELECT f.experiment_key, f.variant, COUNT(*) AS imps
            FROM events e
            JOIN feeds f ON f.feed_uid = (e.payload->>'feed_id')
            WHERE e.event_name = 'product_impression'
              AND e.timestamp_utc >= '#{cutoff.iso8601}'
              AND f.experiment_key IS NOT NULL
            GROUP BY f.experiment_key, f.variant
          ), clicks AS (
            SELECT f.experiment_key, f.variant, COUNT(*) AS clicks
            FROM events e
            JOIN feeds f ON f.feed_uid = (e.payload->>'feed_id')
            WHERE e.event_name = 'product_click'
              AND e.timestamp_utc >= '#{cutoff.iso8601}'
              AND f.experiment_key IS NOT NULL
            GROUP BY f.experiment_key, f.variant
          )
          SELECT 
            i.experiment_key, 
            i.variant,
            i.imps,
            COALESCE(c.clicks, 0) AS clicks,
            ROUND(100.0 * COALESCE(c.clicks, 0) / NULLIF(i.imps, 0), 2) AS ctr_percent
          FROM impressions i
          LEFT JOIN clicks c USING (experiment_key, variant)
          ORDER BY ctr_percent DESC;
        SQL
        
        # Experiment assignment counts
        assignment_data = ExperimentAssignment
          .joins(:experiment)
          .where('assigned_at >= ?', cutoff)
          .group('experiments.key', :variant)
          .count
        
        {
          ctr_by_variant: ctr_data.to_a,
          assignment_counts: assignment_data,
          active_experiments: Experiment.running.count,
          total_assignments: ExperimentAssignment.where('assigned_at >= ?', cutoff).count
        }
      end
      
      def collect_cost_metrics(days = 7)
        cutoff = days.days.ago.to_date
        
        # Cost per 1k calls by plan
        cost_data = ActiveRecord::Base.connection.select_all(<<-SQL)
          SELECT 
            plan_id,
            endpoint,
            SUM(calls) AS total_calls,
            SUM(est_cost_usd) AS total_cost,
            ROUND(1000.0 * SUM(est_cost_usd) / NULLIF(SUM(calls), 0), 4) AS usd_per_1k_calls,
            ROUND(SUM(gpu_seconds), 2) AS total_gpu_seconds,
            ROUND(SUM(cpu_seconds), 2) AS total_cpu_seconds,
            SUM(tokens) AS total_tokens
          FROM api_usage
          WHERE ts >= '#{cutoff}'
          GROUP BY plan_id, endpoint
          ORDER BY total_cost DESC;
        SQL
        
        # Daily cost trends
        daily_costs = ApiUsage
          .where('ts >= ?', cutoff)
          .group(:ts, :plan_id)
          .sum(:est_cost_usd)
        
        {
          cost_by_plan: cost_data.to_a,
          daily_cost_trend: daily_costs,
          total_cost_period: cost_data.sum { |row| row['total_cost'].to_f },
          total_calls_period: cost_data.sum { |row| row['total_calls'].to_i }
        }
      end
      
      def collect_performance_metrics(days = 7)
        cutoff = days.days.ago.to_date
        
        # Plan performance from plan_metrics
        performance_data = PlanMetrics
          .where('metric_date >= ?', cutoff)
          .select(:plan_id, :metric_date, :plan_score, :p95_latency_ms, 
                  :cache_hit_rate, :empty_section_rate, :requests, :errors)
          .order(:metric_date, :plan_id)
        
        # Current SLO status
        latest_metrics = PlanMetrics
          .where('metric_date >= ?', 1.day.ago.to_date)
          .group(:plan_id)
          .average(:p95_latency_ms)
        
        slo_violations = latest_metrics.select { |_, latency| latency.to_f > 1000.0 }
        
        {
          plan_performance: performance_data.map(&:attributes),
          slo_status: {
            latency_violations: slo_violations.keys,
            target_latency_ms: 1000,
            current_max_latency: latest_metrics.values.max&.round(2) || 0
          },
          error_rates: PlanMetrics
            .where('metric_date >= ?', cutoff)
            .group(:plan_id)
            .average('CASE WHEN requests > 0 THEN (errors::float / requests) * 100 ELSE 0 END')
        }
      end
      
      private
      
      def collect_pg_stats
        ActiveRecord::Base.connection.select_one(<<-SQL)
          SELECT 
            numbackends,
            xact_commit,
            xact_rollback,
            blks_read,
            blks_hit,
            tup_returned,
            tup_fetched,
            tup_inserted,
            tup_updated,
            tup_deleted,
            temp_files,
            temp_bytes,
            deadlocks,
            checksum_failures,
            stats_reset
          FROM pg_stat_database 
          WHERE datname = current_database();
        SQL
      end
      
      def collect_replication_lag
        # Check for read replica lag
        lag_data = ActiveRecord::Base.connection.select_one(<<-SQL)
          SELECT 
            CASE 
              WHEN pg_is_in_recovery() THEN 
                EXTRACT(epoch FROM (now() - pg_last_xact_replay_timestamp()))
              ELSE 
                NULL 
            END AS replica_lag_seconds;
        SQL
        
        lag_data&.dig('replica_lag_seconds')&.to_f || 0
      end
      
      def collect_cache_hit_ratio
        ActiveRecord::Base.connection.select_one(<<-SQL)
          SELECT 
            ROUND(
              100.0 * sum(blks_hit) / NULLIF(sum(blks_hit + blks_read), 0), 2
            ) AS cache_hit_ratio
          FROM pg_stat_database;
        SQL
      end
      
      def collect_table_stats
        ActiveRecord::Base.connection.select_all(<<-SQL)
          SELECT 
            schemaname,
            tablename,
            n_tup_ins,
            n_tup_upd,
            n_tup_del,
            n_live_tup,
            n_dead_tup,
            last_vacuum,
            last_autovacuum,
            last_analyze,
            last_autoanalyze
          FROM pg_stat_user_tables
          WHERE schemaname = 'public'
            AND tablename IN ('events', 'feeds', 'feed_items', 'exposure_outcomes', 'plan_metrics')
          ORDER BY n_live_tup DESC;
        SQL
      end
      
      def collect_slow_queries
        # Get top 10 slowest queries from pg_stat_statements
        ActiveRecord::Base.connection.select_all(<<-SQL)
          SELECT 
            query,
            calls,
            total_exec_time,
            mean_exec_time,
            max_exec_time,
            rows,
            shared_blks_hit,
            shared_blks_read
          FROM pg_stat_statements
          WHERE query NOT LIKE '%pg_stat_statements%'
          ORDER BY total_exec_time DESC
          LIMIT 10;
        SQL
      rescue ActiveRecord::StatementInvalid
        # pg_stat_statements extension not available
        []
      end
    end
  end
end
