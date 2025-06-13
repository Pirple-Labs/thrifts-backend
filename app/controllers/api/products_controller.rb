module Api
  class ProductsController < Api::BaseController
    skip_before_action :authenticate_user!, only: [:index]

  # GET /api/products?page=1
    def index
      if current_user.nil? && params[:page].to_i > 2
        render json: { error: "Guest limit reached" }, status: :forbidden
        return
      end

      @products = Product.includes(:shop).order("RANDOM()").page(params[:page])

      render json: @products.as_json(include: {
        shop: {
          only: [:id, :name, :store_logo_url]
        }
      }, except: [:updated_at])
    end


    # POST /api/products
    # POST /api/products
    def create
      shop = current_user.shops.find_by(id: product_params[:shop_id])

      if shop.nil?
        render json: { error: "Shop not found or not owned by user" }, status: :not_found
        return
      end

      product = shop.products.new(
        name: product_params[:name],
        price: product_params[:price],
        description: product_params[:description],
        main_image: product_params[:main_image],
        supplementary_images: product_params[:supplementary_images] || [],
      )

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
        :main_image,                   # ✅ allow string for main_image
        supplementary_images: []      # ✅ allow array for JSONB column
      )
     end

  end
end
