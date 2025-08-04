class Payment < ApplicationRecord
  belongs_to :user
  has_many :orders

  enum status: {
    pending: "pending",
    completed: "completed",
    failed: "failed"
  }

  validates :status, presence: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
