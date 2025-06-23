class Product < ApplicationRecord
     belongs_to :shop
     belongs_to :category, optional: true
     has_many :recommended_products, dependent: :destroy

end
