class ApiUsage < ApplicationRecord
  self.table_name = 'api_usage'
  
  validates :plan_id, presence: true
  validates :endpoint, presence: true
  validates :ts, presence: true
  validates :calls, numericality: { greater_than_or_equal_to: 0 }
  validates :gpu_seconds, numericality: { greater_than_or_equal_to: 0 }
  validates :cpu_seconds, numericality: { greater_than_or_equal_to: 0 }
  validates :tokens, numericality: { greater_than_or_equal_to: 0 }
  validates :est_cost_usd, numericality: { greater_than_or_equal_to: 0 }
  
  scope :for_plan, ->(plan_id) { where(plan_id: plan_id) }
  scope :for_endpoint, ->(endpoint) { where(endpoint: endpoint) }
  scope :recent, ->(days = 7) { where('ts >= ?', Date.current - days.days) }
  scope :today, -> { where(ts: Date.current) }
  
  def self.upsert_usage!(plan_id:, endpoint:, gpu_seconds: 0, cpu_seconds: 0, tokens: 0, est_cost_usd: 0)
    today = Date.current
    
    # Try to find existing record for today
    usage = find_or_initialize_by(
      plan_id: plan_id,
      endpoint: endpoint,
      ts: today
    )
    
    # Update counters
    usage.calls += 1
    usage.gpu_seconds += gpu_seconds
    usage.cpu_seconds += cpu_seconds
    usage.tokens += tokens
    usage.est_cost_usd += est_cost_usd
    
    usage.save!
    usage
  end
  
  def cost_per_call
    return 0.0 if calls.zero?
    est_cost_usd / calls
  end
  
  def total_seconds
    gpu_seconds + cpu_seconds
  end
  
  def cost_per_1k_calls
    return 0.0 if calls.zero?
    (est_cost_usd / calls) * 1000
  end
end
