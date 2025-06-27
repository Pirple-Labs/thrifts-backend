module Api
  class ProductsController < Api::BaseController
    skip_before_action :authenticate_user!, only: [:index]

    # GET /api/products?shop_id=...&page=1&limit=20
    def index
      if current_user.nil? && params[:page].to_i > 2
        render json: { error: "Guest limit reached" }, status: :forbidden
        return
      end

      products = Product.includes(:shop)

      # Merchant filter
      if params[:shop_id].present?
        products = products.where(shop_id: params[:shop_id])
      else
        products = products.order("RANDOM()")
      end

      # Optional out-of-stock filter
      if params[:out_of_stock] == "false"
        products = products.where("stock > 0")
      end

      paginated = products.page(params[:page]).per(params[:limit] || 20)

     render json: {
        data: paginated.as_json(
          include: {
            shop: {
              only: [:id, :name, :store_logo_url]
            }
          },
          except: [:updated_at]
        ),
        page: params[:page].to_i,
        isLastPage: paginated.next_page.nil?
      }
    end

    # POST /api/products
    def create
      shop = current_user.shop

      if shop.nil? || shop.id.to_s != product_params[:shop_id].to_s
        render json: { error: "Shop not found or not owned by user" }, status: :not_found
        return
      end

      product = shop.products.new(product_params)

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
        :main_image,
        :color,
        :size,
        :stock,
        supplementary_images: []
      )
    end
  end
end
