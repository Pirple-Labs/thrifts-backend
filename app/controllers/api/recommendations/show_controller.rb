# app/controllers/api/recommendations/show_controller.rb
module Api
  module Recommendations
    class ShowController < Api::BaseController
      before_action :authenticate_user!

      # GET /api/recommendations/:product_id
      def show
        product = Product.find(params[:product_id])

        render json: {
          complementary: product.complementary_items.map { |p|
            rec = product.complementary_products.find_by(complementary_product_id: p.id)
            {
              id: p.id,
              name: p.name,
              score: rec.score,
              triggered_by: rec.triggered_by
            }
          },
          similar: product.similar_items.map { |p|
            rec = product.similar_products.find_by(similar_product_id: p.id)
            {
              id: p.id,
              name: p.name,
              score: rec.score
            }
          }
        }
      end
    end
  end
end
