

class DailyMetricsRollupJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("[DailyMetricsRollupJob] Running daily cost and error rollup.")
    
    start_time = Time.current
    target_date = 1.day.ago.to_date
    
    # Consolidate daily api_usage data into plan_metrics
    consolidate_cost_data(target_date)
    consolidate_error_data(target_date)
    
    duration = Time.current - start_time
    Rails.logger.info("[DailyMetricsRollupJob] Completed in #{duration.round(2)}s")
  end

  private

  def consolidate_cost_data(target_date)
    # Get all plans that had API usage on the target date
    active_plans = ApiUsage.where(ts: target_date)
                           .distinct
                           .pluck(:plan_id)
                           .compact
    
    if active_plans.empty?
      Rails.logger.info("[DailyMetricsRollupJob] No API usage found for #{target_date}")
      return
    end

    Rails.logger.info("[DailyMetricsRollupJob] Consolidating cost data for #{active_plans.count} plans")
    
    # Update plan_metrics with cost data
    active_plans.each do |plan_id|
      consolidate_plan_costs(plan_id, target_date)
    end
  end

  def consolidate_plan_costs(plan_id, target_date)
    # Aggregate cost data for this plan on the target date
    usage_data = ApiUsage.where(plan_id: plan_id, ts: target_date)
    
    total_cost = usage_data.sum(:est_cost_usd)
    total_calls = usage_data.sum(:calls)
    total_gpu_seconds = usage_data.sum(:gpu_seconds)
    total_cpu_seconds = usage_data.sum(:cpu_seconds)
    total_tokens = usage_data.sum(:tokens)
    
    # Find or create plan_metrics record
    plan_metric = PlanMetric.find_or_initialize_by(
      plan_id: plan_id,
      metric_date: target_date
    )
    
    # Update with cost data
    plan_metric.est_cost_usd = total_cost
    plan_metric.requests = total_calls
    
    # Add cost breakdown to metadata (optional)
    plan_metric.metadata ||= {}
    plan_metric.metadata[:cost_breakdown] = {
      gpu_seconds: total_gpu_seconds,
      cpu_seconds: total_cpu_seconds,
      tokens: total_tokens,
      cost_per_call: total_calls.zero? ? 0.0 : (total_cost / total_calls).round(6)
    }
    
    plan_metric.save!
    
    Rails.logger.info("[DailyMetricsRollupJob] Updated costs for plan #{plan_id}: $#{total_cost.round(4)} (#{total_calls} calls)"
  rescue => e
    Rails.logger.error "[DailyMetricsRollupJob] Failed to consolidate costs for plan #{plan_id}: #{e.message}"
  end

  def consolidate_error_data(target_date)
    # This would typically come from error tracking/monitoring systems
    # For now, we'll use a placeholder approach
    
    # Get all plans that had activity on the target date
    active_plans = Feed.where("DATE(created_at) = ?", target_date)
                       .distinct
                       .pluck(:plan_id)
                       .compact
    
    active_plans.each do |plan_id|
      # Placeholder: would need actual error tracking
      # For now, set to 0 (no errors tracked)
      plan_metric = PlanMetric.find_by(plan_id: plan_id, metric_date: target_date)
      next unless plan_metric
      
      plan_metric.errors = 0 # Placeholder
      plan_metric.save!
    end
  end

  def calculate_cost_per_1k_calls(plan_id, target_date)
    usage_data = ApiUsage.where(plan_id: plan_id, ts: target_date)
    total_cost = usage_data.sum(:est_cost_usd)
    total_calls = usage_data.sum(:calls)
    
    return 0.0 if total_calls.zero?
    (total_cost / total_calls * 1000).round(6)
  end

  def generate_cost_report(target_date)
    # Generate a summary report of costs for the target date
    report = {
      date: target_date,
      total_cost: 0.0,
      total_calls: 0,
      plans: []
    }
    
    ApiUsage.where(ts: target_date).group(:plan_id).sum(:est_cost_usd).each do |plan_id, cost|
      calls = ApiUsage.where(plan_id: plan_id, ts: target_date).sum(:calls)
      cost_per_1k = calculate_cost_per_1k_calls(plan_id, target_date)
      
      report[:plans] << {
        plan_id: plan_id,
        total_cost: cost,
        total_calls: calls,
        cost_per_1k_calls: cost_per_1k
      }
      
      report[:total_cost] += cost
      report[:total_calls] += calls
    end
    
    # Store report in cache for monitoring
    Rails.cache.write("cost_report:#{target_date}", report, expires_in: 1.week)
    
    Rails.logger.info("[DailyMetricsRollupJob] Cost report for #{target_date}: $#{report[:total_cost].round(4)} total, #{report[:total_calls]} calls")
    
    report
  end
end
