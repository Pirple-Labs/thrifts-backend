module Api
  class ProductsController < ApplicationController
    skip_before_action :authenticate_user!, only: [:index]

    def index
      if current_user.nil? && params[:page].to_i > 2
        render json: { error: "Guest limit reached" }, status: :forbidden
        return
      end

      @products = Product.order("RANDOM()").page(params[:page]).per(params[:limit])
      render json: @products
    end
  end
end
