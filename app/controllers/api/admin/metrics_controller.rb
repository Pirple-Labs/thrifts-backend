module Api
  module Admin
    class MetricsController < Api::BaseController
      # Admin endpoint for monitoring and observability
      # TODO: Add proper admin authentication
      
      # GET /api/admin/metrics/database
      def database
        metrics = Monitoring::MetricsCollector.collect_database_metrics
        render json: metrics
      end
      
      # GET /api/admin/metrics/business?days=7
      def business
        days = params[:days]&.to_i || 7
        days = [days, 30].min # Max 30 days
        
        metrics = Monitoring::MetricsCollector.collect_business_metrics(days)
        render json: metrics
      end
      
      # GET /api/admin/metrics/experiments?days=7
      def experiments
        days = params[:days]&.to_i || 7
        days = [days, 30].min
        
        experiment_metrics = Monitoring::MetricsCollector.collect_experiment_metrics(days)
        render json: experiment_metrics
      end
      
      # GET /api/admin/metrics/costs?days=7
      def costs
        days = params[:days]&.to_i || 7
        days = [days, 30].min
        
        cost_metrics = Monitoring::MetricsCollector.collect_cost_metrics(days)
        render json: cost_metrics
      end
      
      # GET /api/admin/metrics/performance?days=7
      def performance
        days = params[:days]&.to_i || 7
        days = [days, 30].min
        
        performance_metrics = Monitoring::MetricsCollector.collect_performance_metrics(days)
        render json: performance_metrics
      end
      
      # GET /api/admin/metrics/slo_status
      def slo_status
        # Current SLO status for alerts/dashboards
        status = check_slo_compliance
        
        render json: {
          slo_status: status,
          timestamp: Time.current.iso8601,
          targets: {
            p95_latency_ms: 1000,
            error_rate_percent: 0.5,
            cache_hit_rate_percent: 95,
            replica_lag_seconds: 60
          }
        }
      end
      
      # POST /api/admin/metrics/experiments/:key/status
      def update_experiment_status
        experiment = Experiment.find_by!(key: params[:key])
        new_status = params[:status]
        
        unless %w[draft running paused complete].include?(new_status)
          return render json: { error: "Invalid status" }, status: :bad_request
        end
        
        experiment.update!(status: new_status)
        
        render json: {
          experiment_key: experiment.key,
          status: experiment.status,
          traffic_pct: experiment.traffic_pct,
          updated_at: experiment.updated_at.iso8601
        }
      end
      
      # POST /api/admin/metrics/experiments/:key/traffic
      def update_experiment_traffic
        experiment = Experiment.find_by!(key: params[:key])
        new_traffic = params[:traffic_pct]&.to_i
        
        unless new_traffic && new_traffic.between?(0, 100)
          return render json: { error: "Invalid traffic_pct (0-100)" }, status: :bad_request
        end
        
        experiment.update!(traffic_pct: new_traffic)
        
        render json: {
          experiment_key: experiment.key,
          status: experiment.status,
          traffic_pct: experiment.traffic_pct,
          updated_at: experiment.updated_at.iso8601
        }
      end
      
      private
      
      def check_slo_compliance
        # Get latest metrics for SLO checking
        latest_plan_metrics = PlanMetrics
          .where('metric_date >= ?', 1.day.ago.to_date)
          .group(:plan_id)
          .select('plan_id, AVG(p95_latency_ms) as avg_latency, AVG(cache_hit_rate) as avg_cache_hit, AVG(CASE WHEN requests > 0 THEN (errors::float / requests) * 100 ELSE 0 END) as error_rate')
        
        replica_lag = Monitoring::MetricsCollector.send(:collect_replication_lag)
        
        violations = []
        
        latest_plan_metrics.each do |metric|
          plan_id = metric.plan_id
          
          if metric.avg_latency.to_f > 1000
            violations << {
              type: 'latency',
              plan_id: plan_id,
              value: metric.avg_latency.round(2),
              threshold: 1000,
              severity: 'warning'
            }
          end
          
          if metric.error_rate.to_f > 0.5
            violations << {
              type: 'error_rate',
              plan_id: plan_id,
              value: metric.error_rate.round(2),
              threshold: 0.5,
              severity: 'critical'
            }
          end
          
          if metric.avg_cache_hit.to_f < 0.95
            violations << {
              type: 'cache_hit_rate',
              plan_id: plan_id,
              value: (metric.avg_cache_hit * 100).round(2),
              threshold: 95,
              severity: 'warning'
            }
          end
        end
        
        if replica_lag > 60
          violations << {
            type: 'replica_lag',
            plan_id: nil,
            value: replica_lag.round(2),
            threshold: 60,
            severity: 'critical'
          }
        end
        
        {
          compliant: violations.empty?,
          violations: violations,
          summary: {
            total_violations: violations.count,
            critical_violations: violations.count { |v| v[:severity] == 'critical' },
            warning_violations: violations.count { |v| v[:severity] == 'warning' }
          }
        }
      end
    end
  end
end
