class Order < ApplicationRecord
  belongs_to :user
  belongs_to :payment, optional: true

  has_many :order_items, dependent: :destroy
  has_one :shop, through: :order_items  # useful shortcut

  validates :status, presence: true
end
