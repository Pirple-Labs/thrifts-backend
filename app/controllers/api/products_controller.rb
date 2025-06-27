module Api
  class ProductsController < Api::BaseController
    skip_before_action :authenticate_user!, only: [:index]

   def index
  if current_user.nil? && params[:page].to_i > 2
    render json: { error: "Guest limit reached" }, status: :forbidden
    return
  end

  products = Product.includes(:shop, :category)

  is_merchant_viewing_own_shop = current_user&.shop&.id.to_s == params[:shop_id].to_s

  # Apply filtering
  products = if params[:shop_id].present?
               products.where(shop_id: params[:shop_id])
             else
               products.order("RANDOM()")
             end

  # 👇 Only apply stock > 0 for non-merchants (public views)
  unless is_merchant_viewing_own_shop
    products = products.where("stock > 0")
  end

  paginated = products.page(params[:page]).per(params[:limit] || 20)

  render json: {
    data: paginated.as_json(
      include: {
        shop: { only: [:id, :name, :store_logo_url] },
        category: { only: [:id, :name] }
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

    # PATCH /api/products/:id
    def update
      product = current_user.shop&.products&.find_by(id: params[:id])

      if product.nil?
        render json: { error: "Product not found or not authorized" }, status: :not_found
        return
      end

      if product.update(product_params)
        render json: { message: "Product updated successfully", product: product }
      else
        render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/products/:id
    def destroy
      product = current_user.shop&.products&.find_by(id: params[:id])

      if product.nil?
        render json: { error: "Product not found or unauthorized" }, status: :not_found
        return
      end

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
