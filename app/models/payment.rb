# app/models/payment.rb
class Payment < ApplicationRecord
  belongs_to :user
  has_many :orders

  enum :status, {
    pending:   "pending",
    success:   "success",
    failed:    "failed",
    cancelled: "cancelled",
    timeout:   "timeout"
  }

  validates :status, presence: true
  validates :amount, numericality: { only_integer: true, greater_than: 0 }, allow_nil: false
  # Keep total_amount if you still use it elsewhere
end
