class ComplementaryProduct < ApplicationRecord
  belongs_to :product
  belongs_to :complementary, class_name: "Product", foreign_key: :complementary_product_id
end