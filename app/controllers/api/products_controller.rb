module Api
  class ProductsController < Api::BaseController
    def index
      if guest_limit_reached?
        render json: { error: "Guest limit reached" }, status: :forbidden
        return
      end

      products = Product.includes(:shop, :category)
      is_merchant = merchant_owns_shop?

      products = filter_by_shop(products)
      products = products.where("stock > 0") unless is_merchant

      paginated = products.page(params[:page]).per(params[:limit] || 20)

      render json: {
        data: serialize_products(paginated),
        page: params[:page].to_i,
        isLastPage: paginated.next_page.nil?
      }
    end

    def show
        product = Product.find(params[:id])
        render json: { product: product }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Product not found" }, status: :not_found
      end


    def create
      product = current_user.shop&.products&.new(product_params.except(:shop_id))

      if product&.save
        render json: { message: "Product created successfully", product: serialize_product(product) }, status: :created
      else
        render json: { errors: product&.errors&.full_messages || ["Shop not found"] }, status: :unprocessable_entity
      end
    end

    def update
      product = Product.find_by(id: params[:id])

      if product.nil?
        render json: { error: "Product not found" }, status: :not_found
      elsif product.shop.user_id != current_user.id
        render json: { error: "Not authorized to update this product" }, status: :forbidden
      elsif product.update(product_params.except(:shop_id))
        render json: { message: "Product updated successfully", product: serialize_product(product) }
      else
        render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      product = Product.find_by(id: params[:id])

      if product.nil?
        render json: { error: "Product not found" }, status: :not_found
      elsif product.shop.user_id != current_user.id
        render json: { error: "Not authorized to delete this product" }, status: :forbidden
      else
        begin
          product.destroy!
          render json: { message: "Product deleted successfully" }, status: :ok
        rescue ActiveRecord::InvalidForeignKey => e
          render json: {
            error: "Cannot delete product because it is referenced elsewhere (e.g. wishlist)",
            detail: e.message
          }, status: :unprocessable_entity
        end
      end
    end

    private

    def product_params
      params.require(:product).permit(
        :name, :price, :description, :main_image, :category_id, :color, :size, :stock,
        supplementary_images: []
      )
    end

    def guest_limit_reached?
      current_user.nil? && params[:page].to_i > 2
    end

    def merchant_owns_shop?
      current_user&.shop&.id.to_s == params[:shop_id].to_s
    end

    def filter_by_shop(products)
      if params[:shop_id].present?
        products.where(shop_id: params[:shop_id])
      else
        products.order("RANDOM()")
      end
    end

    def serialize_products(products)
      products.as_json(
        only: [
          :id, :name, :description, :price, :main_image, :supplementary_images,
          :color, :size, :stock, :category_id, :shop_id, :views, :created_at
        ],
        include: {
          shop: { only: [:id, :name, :store_logo_url] },
          category: { only: [:id, :name] }
        }
      )
    end

    def serialize_product(product)
      product.as_json(
        only: [
          :id, :name, :description, :price, :main_image, :supplementary_images,
          :color, :size, :stock, :category_id, :shop_id, :views, :created_at
        ],
        include: {
          shop: { only: [:id, :name, :store_logo_url] },
          category: { only: [:id, :name] }
        }
      )
    end
  end
end
