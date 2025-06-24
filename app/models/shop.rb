class Shop < ApplicationRecord
  belongs_to :user

  has_many :products, dependent: :destroy
  validates :description, presence: true
  validates :name, presence: true, uniqueness: { scope: :user_id }
  has_many :order_items, through: :products
  has_many :orders, -> { distinct }, through: :order_items
end
