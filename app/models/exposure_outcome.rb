class ExposureOutcome < ApplicationRecord
  # Validations
  validates :feed_uid, presence: true
  validates :plan_id, presence: true
  validates :section, presence: true
  validates :product_id, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :item_weight_w1, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :window_start, presence: true
  validates :window_end, presence: true

  # Associations
  belongs_to :product
  belongs_to :feed, foreign_key: :feed_uid, primary_key: :feed_uid

  # Scopes
  scope :for_plan, ->(plan_id) { where(plan_id: plan_id) }
  scope :for_date, ->(date) { where("DATE(window_start) = ?", date) }
  scope :clicked, -> { where(clicked_5m: true) }
  scope :added_to_cart, -> { where(atc_30m: true) }
  scope :purchased, -> { where(purchased_24h: true) }

  # Class methods
  def self.join_success_rate(plan_id, date)
    total_exposures = where(plan_id: plan_id, window_start: date.beginning_of_day..date.end_of_day).count
    return 0.0 if total_exposures.zero?
    
    successful_joins = where(plan_id: plan_id, window_start: date.beginning_of_day..date.end_of_day)
                       .where("clicked_5m = true OR atc_30m = true OR purchased_24h = true")
                       .count
    
    (successful_joins.to_f / total_exposures * 100).round(2)
  end

  def self.average_item_weight(plan_id, date)
    where(plan_id: plan_id, window_start: date.beginning_of_day..date.end_of_day)
      .average(:item_weight_w1)
      .to_f
      .round(4)
  end

  # Instance methods
  def has_engagement?
    clicked_5m || atc_30m || purchased_24h
  end

  def engagement_score
    score = 0
    score += 1 if clicked_5m
    score += 5 if atc_30m
    score += 20 if purchased_24h
    score
  end

  def position_discount
    1.0 / Math.log2(2 + position)
  end

  def recalculate_weight!
    base_weight = engagement_score
    discount = position_discount
    new_weight = (base_weight * discount).round(4)
    
    update!(item_weight_w1: new_weight)
  end
end
