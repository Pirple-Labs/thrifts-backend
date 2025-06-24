class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product
  delegate :shop, to: :product
end
