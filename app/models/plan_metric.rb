class PlanMetric < ApplicationRecord
  # Validations
  validates :plan_id, presence: true
  validates :metric_date, presence: true
  validates :plan_score, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :p95_latency_ms, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :cache_hit_rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :empty_section_rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :requests, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :est_cost_usd, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :errors, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Uniqueness
  validates :plan_id, uniqueness: { scope: :metric_date }

  # Scopes
  scope :for_plan, ->(plan_id) { where(plan_id: plan_id) }
  scope :for_date_range, ->(start_date, end_date) { where(metric_date: start_date..end_date) }
  scope :recent, ->(days = 7) { where("metric_date >= ?", days.days.ago.to_date) }
  scope :high_performing, -> { where("plan_score > ?", 10.0) }
  scope :low_latency, -> { where("p95_latency_ms < ?", 1000) }

  # Class methods
  def self.average_score(plan_id, days = 7)
    for_plan(plan_id)
      .recent(days)
      .average(:plan_score)
      .to_f
      .round(4)
  end

  def self.average_latency(plan_id, days = 7)
    for_plan(plan_id)
      .recent(days)
      .average(:p95_latency_ms)
      .to_f
      .round(2)
  end

  def self.cost_per_request(plan_id, days = 7)
    metrics = for_plan(plan_id).recent(days)
    total_cost = metrics.sum(:est_cost_usd)
    total_requests = metrics.sum(:requests)
    
    return 0.0 if total_requests.zero?
    (total_cost / total_requests).round(6)
  end

  def self.error_rate(plan_id, days = 7)
    metrics = for_plan(plan_id).recent(days)
    total_errors = metrics.sum(:errors)
    total_requests = metrics.sum(:requests)
    
    return 0.0 if total_requests.zero?
    (total_errors.to_f / total_requests * 100).round(4)
  end

  def self.performance_summary(plan_id, days = 7)
    metrics = for_plan(plan_id).recent(days)
    
    {
      avg_score: average_score(plan_id, days),
      avg_latency: average_latency(plan_id, days),
      avg_cache_hit: metrics.average(:cache_hit_rate).to_f.round(4),
      avg_empty_section: metrics.average(:empty_section_rate).to_f.round(4),
      total_requests: metrics.sum(:requests),
      total_cost: metrics.sum(:est_cost_usd).round(4),
      cost_per_request: cost_per_request(plan_id, days),
      error_rate: error_rate(plan_id, days)
    }
  end

  # Instance methods
  def cost_per_request
    return 0.0 if requests.zero?
    (est_cost_usd / requests).round(6)
  end

  def error_rate_percent
    return 0.0 if requests.zero?
    (errors.to_f / requests * 100).round(4)
  end

  def performance_grade
    case plan_score
    when 0..5
      'D'
    when 5..10
      'C'
    when 10..20
      'B'
    when 20..30
      'A'
    else
      'A+'
    end
  end

  def latency_grade
    case p95_latency_ms
    when 0..500
      'A'
    when 500..1000
      'B'
    when 1000..2000
      'C'
    else
      'D'
    end
  end

  def cache_grade
    case cache_hit_rate
    when 0.9..1.0
      'A'
    when 0.7..0.9
      'B'
    when 0.5..0.7
      'C'
    else
      'D'
    end
  end
end
