class DeliveryAddress < ApplicationRecord
  belongs_to :user

  validates :nickname, :phone, :location, :pickup_agent, presence: true
end
