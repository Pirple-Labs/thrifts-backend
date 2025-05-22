class Shop < ApplicationRecord
  belongs_to :user

  validates :description, presence: true
  validates :name, presence: true, uniqueness: { scope: :user_id }
end
