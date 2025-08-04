class ModerationEvent < ApplicationRecord
  belongs_to :product
  # belongs_to :user

  validates :predicted_label, :final_label, presence: true
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
end
