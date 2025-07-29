# app/models/similar_product.rb
class SimilarProduct < ApplicationRecord
  belongs_to :product
  belongs_to :similar, class_name: "Product", foreign_key: :similar_product_id
end