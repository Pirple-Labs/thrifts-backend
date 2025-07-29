module Api
  class RecommendedProductsController < ApplicationController
    before_action :authenticate_user!

    def index
      recommended = ::RecommendedProduct
        .includes(:product)
        .where(user: current_user)
        .order(:rank)
        .limit(20)

      picks = recommended.map do |rec|
        product = rec.product
        next unless product

    {
    product_id: product.id,
    name: product.name,
    main_image: product.main_image,
    supplementary_images: product.supplementary_images,
    price: product.price,
    description: product.description,
    views: product.views,
    shop_name: product.shop&.name,
    rank: rec.rank,
    reason: rec.reason
  }    
    end.compact

      render json: { success: true, picks: picks }
    rescue => e
      render json: {
        success: false,
        error: e.message,
        trace: Rails.env.development? ? e.backtrace.first(5) : nil
      }, status: :internal_server_error
    end
  end
end
