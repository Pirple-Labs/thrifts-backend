# app/controllers/api/recommendations_controller.rb
require 'httparty'
module Api
  class RecommendationsController < Api::BaseController

    before_action :authenticate_user!

    # GET  /api/recommendations/:product_id
    def show
      product = Product.find(params[:product_id])
      render json: {
        complementary: product.complementary_items.map { |p|
          rec = product.complementary_products.find_by(complementary_product_id: p.id)
          { id: p.id, name: p.name, score: rec.score, triggered_by: rec.triggered_by }
        },
        similar: product.similar_items.map { |p|
          rec = product.similar_products.find_by(similar_product_id: p.id)
          { id: p.id, name: p.name, score: rec.score }
        }
      }
    end

    # POST /api/recommendations/:product_id/refresh
    def refresh
      product = Product.find(params[:product_id])
      flask = HTTParty.post("http://localhost:5000/api/recommendations/#{product.id}")
      data  = JSON.parse(flask.body)

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
      render json: { error: e.message }, status: 500
    end
  end
end
