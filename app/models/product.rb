class Product < ApplicationRecord
     belongs_to :shop
     belongs_to :category, optional: true
     has_many :recommended_products, dependent: :destroy
      # 🔒 Inventory check
      validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

end
