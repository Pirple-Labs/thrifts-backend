module Api
  class ProductsController < Api::BaseController
    skip_before_action :authenticate_user!, only: [:index]

    # GET /api/products?page=1
    def index
      if current_user.nil? && params[:page].to_i > 2
        render json: { error: "Guest limit reached" }, status: :forbidden
        return
      end

      @products = Product.order("RANDOM()").page(params[:page])
      render json: @products
    end

    # POST /api/products
    def create
      shop = current_user.shops.find_by(id: product_params[:shop_id])

      if shop.nil?
        render json: { error: "Shop not found or not owned by user" }, status: :not_found
        return
      end

      product = shop.products.new(product_params.to_h.merge({
        product_image: product_params[:product_images]&.first # fallback for main image
      }))

      if product.save
        render json: { message: "Product created successfully", product: product }, status: :created
      else
        render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def product_params
      params.require(:product).permit(
        :name,
        :price,
        :description,
        :shop_id,
        product_images: [] # permit array of URLs
      )
    end
  end
end
