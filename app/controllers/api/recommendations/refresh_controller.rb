# app/controllers/api/recommendations/refresh_controller.rb

module Api
  module Recommendations
    class RefreshController < Api::BaseController
      before_action :authenticate_user!

      # POST /api/recommendations/:product_id/refresh
      def refresh
        product = Product.find(params[:product_id])

        data = RecommendationService.refresh_for(product.id)

        # Persist similar
        product.similar_products.delete_all
        Array(data["similar"]).each do |sp|
          product.similar_products.create!(
            similar_product_id: sp["product_id"],
            score: sp["score"]
          )
        end

        # Persist complementary
        product.complementary_products.delete_all
        Array(data["complementary"]).each do |cp|
          product.complementary_products.create!(
            complementary_product_id: cp["product_id"],
            score: cp["score"],
            triggered_by: cp["triggered_by"]
          )
        end

        render json: { message: "Recommendations refreshed for product #{product.id}" }
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end
    end
  end
end
