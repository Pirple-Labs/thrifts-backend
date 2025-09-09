# frozen_string_literal: true

class FeedExposure < ApplicationRecord
  # Associations
  belongs_to :feed
  belongs_to :product
  
  # Validations
  validates :feed_id, presence: true
  validates :product_id, presence: true
  validates :section_id, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :profile_hash, presence: true
  validates :reason_hash, presence: true
  validates :propensity, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :latency_ms_retrieval, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :latency_ms_guardrails, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :latency_ms_coord, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :latency_ms_total, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  # Scopes
  scope :for_feed, ->(feed_id) { where(feed_id: feed_id) }
  scope :for_section, ->(section_id) { where(section_id: section_id) }
  scope :for_plan, ->(plan_id) { joins(:feed).where(feeds: { plan_id: plan_id }) }
  scope :by_position, -> { order(:position) }
  scope :high_propensity, -> { where("propensity > ?", 0.7) }
  scope :low_latency, -> { where("latency_ms_total < ?", 1000) }
  
  # Class methods
  def self.average_latency_by_stage(plan_id)
    for_plan(plan_id).group(:section_id).average([
      :latency_ms_retrieval,
      :latency_ms_guardrails,
      :latency_ms_coord,
      :latency_ms_total
    ])
  end
  
  def self.propensity_distribution(plan_id)
    for_plan(plan_id).group("CASE 
      WHEN propensity >= 0.8 THEN 'high'
      WHEN propensity >= 0.5 THEN 'medium'
      ELSE 'low'
    END").count
  end
  
  def self.guardrail_drop_analysis(plan_id)
    for_plan(plan_id)
      .where.not(guardrail_drops: nil)
      .pluck(:guardrail_drops)
      .flatten
      .group_by { |drop| drop["reason"] }
      .transform_values(&:count)
  end
  
  def self.performance_summary(plan_id)
    exposures = for_plan(plan_id)
    
    {
      total_exposures: exposures.count,
      avg_propensity: exposures.average(:propensity).to_f.round(4),
      avg_retrieval_latency: exposures.average(:latency_ms_retrieval).to_f.round(2),
      avg_guardrails_latency: exposures.average(:latency_ms_guardrails).to_f.round(2),
      avg_coordination_latency: exposures.average(:latency_ms_coord).to_f.round(2),
      avg_total_latency: exposures.average(:latency_ms_total).to_f.round(2),
      sections_count: exposures.distinct.count(:section_id),
      high_propensity_count: exposures.high_propensity.count,
      low_latency_count: exposures.low_latency.count
    }
  end
  
  # Instance methods
  def latency_breakdown
    {
      retrieval: latency_ms_retrieval,
      guardrails: latency_ms_guardrails,
      coordination: latency_ms_coord,
      total: latency_ms_total
    }
  end
  
  def performance_grade
    case latency_ms_total
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
  
  def propensity_grade
    case propensity
    when 0.8..1.0
      'A'
    when 0.6..0.8
      'B'
    when 0.4..0.6
      'C'
    else
      'D'
    end
  end
  
  def guardrail_drops_count
    return 0 unless guardrail_drops.present?
    guardrail_drops.values.sum
  end
  
  def pre_guard_candidates_count
    return 0 unless pre_guard_candidates.present?
    pre_guard_candidates.size
  end
  
  def guardrail_efficiency
    return 1.0 if pre_guard_candidates_count.zero?
    (1.0 - guardrail_drops_count.to_f / pre_guard_candidates_count).round(4)
  end
end

