class Shop < ApplicationRecord
  belongs_to :user

  has_many :products, dependent: :destroy
  validates :description, presence: true
  validates :name, presence: true, uniqueness: { scope: :user_id }
end
