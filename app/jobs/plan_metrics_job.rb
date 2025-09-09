class PlanMetricsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("[PlanMetricsJob] Running daily plan metrics aggregation.")
    
    start_time = Time.current
    target_date = 1.day.ago.to_date
    
    # Aggregate metrics for the target date
    aggregate_daily_metrics(target_date)
    
    duration = Time.current - start_time
    Rails.logger.info("[PlanMetricsJob] Completed in #{duration.round(2)}s")
  end

  private

  def aggregate_daily_metrics(target_date)
    # Get all plans that had activity on the target date
    active_plans = get_active_plans(target_date)
    
    if active_plans.empty?
      Rails.logger.info("[PlanMetricsJob] No active plans found for #{target_date}"
      return
    end

    Rails.logger.info("[PlanMetricsJob] Processing #{active_plans.count} active plans")
    
    # Process each plan
    processed_count = 0
    error_count = 0
    
    active_plans.each do |plan_id|
      begin
        process_plan_metrics(plan_id, target_date)
        processed_count += 1
      rescue => e
        error_count += 1
        Rails.logger.error "[PlanMetricsJob] Error processing plan #{plan_id}: #{e.message}"
      end
    end
    
    # Log completion stats
    Rails.logger.info("[PlanMetricsJob] Processed: #{processed_count}, Errors: #{error_count}")
  end

  def get_active_plans(target_date)
    # Get plans that had feeds created on the target date
    Feed.where("DATE(created_at) = ?", target_date)
        .distinct
        .pluck(:plan_id)
        .compact
  end

  def process_plan_metrics(plan_id, target_date)
    # Get exposure outcomes for this plan on the target date
    outcomes = get_plan_outcomes(plan_id, target_date)
    
    # Calculate plan score
    plan_score = calculate_plan_score(outcomes)
    
    # Get performance metrics
    performance_metrics = get_performance_metrics(plan_id, target_date)
    
    # Get cost metrics
    cost_metrics = get_cost_metrics(plan_id, target_date)
    
    # Upsert plan metrics
    upsert_plan_metrics(plan_id, target_date, plan_score, performance_metrics, cost_metrics)
  end

  def get_plan_outcomes(plan_id, target_date)
    ExposureOutcome.where(plan_id: plan_id)
                   .where("DATE(window_start) = ?", target_date)
  end

  def calculate_plan_score(outcomes)
    return 0.0 if outcomes.empty?
    
    # Base score: sum of item weights
    base_score = outcomes.sum(:item_weight_w1)
    
    # Coverage bonus: reward plans that show more items
    coverage_bonus = calculate_coverage_bonus(outcomes)
    
    # Diversity bonus: reward plans with varied categories/shops
    diversity_bonus = calculate_diversity_bonus(outcomes)
    
    # Empty section penalty: penalize plans with empty sections
    empty_penalty = calculate_empty_section_penalty(outcomes)
    
    final_score = base_score + coverage_bonus + diversity_bonus - empty_penalty
    
    [final_score, 0.0].max.round(4) # Ensure non-negative
  end

  def calculate_coverage_bonus(outcomes)
    # Bonus for showing more unique products
    unique_products = outcomes.distinct.count(:product_id)
    
    case unique_products
    when 0..10
      0.0
    when 11..25
      0.5
    when 26..50
      1.0
    else
      2.0
    end
  end

  def calculate_diversity_bonus(outcomes)
    # Bonus for variety in categories and shops
    product_ids = outcomes.distinct.pluck(:product_id)
    products = Product.where(id: product_ids).includes(:category, :shop)
    
    categories = products.map(&:category).compact.uniq.count
    shops = products.map(&:shop).compact.uniq.count
    
    category_bonus = [categories * 0.1, 1.0].min
    shop_bonus = [shops * 0.05, 0.5].min
    
    (category_bonus + shop_bonus).round(4)
  end

  def calculate_empty_section_penalty(outcomes)
    # Penalty for plans that result in empty sections
    # This would need to be calculated from feed data
    # For now, return 0 (placeholder)
    0.0
  end

  def get_performance_metrics(plan_id, target_date)
    # Get performance data from the target date
    feeds = Feed.where(plan_id: plan_id)
                .where("DATE(created_at) = ?", target_date)
    
    return {
      requests: 0,
      p95_latency_ms: 0.0,
      cache_hit_rate: 0.0,
      empty_section_rate: 0.0
    } if feeds.empty?
    
    # Count requests
    requests = feeds.count
    
    # Calculate cache hit rate (placeholder - would need actual cache metrics)
    cache_hit_rate = calculate_cache_hit_rate(plan_id, target_date)
    
    # Calculate empty section rate (placeholder - would need section data)
    empty_section_rate = calculate_empty_section_rate(plan_id, target_date)
    
    # P95 latency would come from actual request timing data
    # For now, use a placeholder
    p95_latency_ms = 250.0 # Placeholder
    
    {
      requests: requests,
      p95_latency_ms: p95_latency_ms,
      cache_hit_rate: cache_hit_rate,
      empty_section_rate: empty_section_rate
    }
  end

  def get_cost_metrics(plan_id, target_date)
    # Get cost data from api_usage table
    usage = ApiUsage.where(plan_id: plan_id, ts: target_date)
    
    return {
      est_cost_usd: 0.0,
      errors: 0
    } if usage.empty?
    
    total_cost = usage.sum(:est_cost_usd)
    total_errors = usage.sum(:errors)
    
    {
      est_cost_usd: total_cost,
      errors: total_errors
    }
  end

  def calculate_cache_hit_rate(plan_id, target_date)
    # Placeholder: would need actual cache hit/miss data
    # For now, return a reasonable default
    0.75
  end

  def calculate_empty_section_rate(plan_id, target_date)
    # Placeholder: would need actual section data
    # For now, return a reasonable default
    0.02
  end

  def upsert_plan_metrics(plan_id, target_date, plan_score, performance_metrics, cost_metrics)
    PlanMetric.upsert(
      {
        plan_id: plan_id,
        metric_date: target_date,
        plan_score: plan_score,
        p95_latency_ms: performance_metrics[:p95_latency_ms],
        cache_hit_rate: performance_metrics[:cache_hit_rate],
        empty_section_rate: performance_metrics[:empty_section_rate],
        requests: performance_metrics[:requests],
        est_cost_usd: cost_metrics[:est_cost_usd],
        errors: cost_metrics[:errors],
        created_at: Time.current,
        updated_at: Time.current
      },
      unique_by: [:plan_id, :metric_date],
      on_duplicate: Arel.sql(<<~SQL)
        plan_score = EXCLUDED.plan_score,
        p95_latency_ms = EXCLUDED.p95_latency_ms,
        cache_hit_rate = EXCLUDED.cache_hit_rate,
        empty_section_rate = EXCLUDED.empty_section_rate,
        requests = EXCLUDED.requests,
        est_cost_usd = EXCLUDED.est_cost_usd,
        errors = EXCLUDED.errors,
        updated_at = EXCLUDED.updated_at
      SQL
    )
  end
end


