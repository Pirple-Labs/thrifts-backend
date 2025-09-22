# frozen_string_literal: true

class ProductRelation < ApplicationRecord
  belongs_to :seed_product, class_name: 'Product', foreign_key: 'seed_id'
  belongs_to :cand_product, class_name: 'Product', foreign_key: 'cand_id'

  validates :rel_type, inclusion: { in: %w[complement similar] }
  validates :score, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :region, presence: true

  scope :complements, -> { where(rel_type: 'complement') }
  scope :similar, -> { where(rel_type: 'similar') }
  scope :for_region, ->(region) { where(region: region) }
  scope :high_confidence, -> { where('score >= ?', 0.7) }
end



