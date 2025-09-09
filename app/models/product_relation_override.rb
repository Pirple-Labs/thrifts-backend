# frozen_string_literal: true

class ProductRelationOverride < ApplicationRecord
  belongs_to :seed_product, class_name: 'Product', foreign_key: 'seed_id'
  belongs_to :cand_product, class_name: 'Product', foreign_key: 'cand_id'

  validates :action, inclusion: { in: %w[boost block] }
  validates :weight, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :seed_id, uniqueness: { scope: :cand_id }

  scope :boosts, -> { where(action: 'boost') }
  scope :blocks, -> { where(action: 'block') }
end
