# frozen_string_literal: true

class HintResolution < ApplicationRecord
  validates :request_id, presence: true
  validates :page, presence: true
  validates :section_id, presence: true
  validates :hint_text, presence: true
  validates :confidence, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  scope :high_confidence, -> { where('confidence >= ?', 0.6) }
  scope :for_request, ->(request_id) { where(request_id: request_id) }
  scope :recent, -> { where('created_at >= ?', 1.day.ago) }
end





