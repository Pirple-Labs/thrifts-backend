module Api
  class ProductsController < Api::BaseController
    before_action :authenticate_user!, except: [:index, :show]

    # GET /api/products
    def index
      if guest_limit_reached?
        return render json: { error: "Guest limit reached" }, status: :forbidden
      end

      products = Product.includes(:shop, :category)
      is_merchant = merchant_owns_shop?

      # Filter by shop if provided
      products = filter_by_shop(products)

      # Only available, approved items for non‑merchants
      unless is_merchant
        products = products.where("stock > 0")
        products = products.where(moderation_status: "approved")
      end

      # Only return products updated since a given timestamp, if provided
      if params[:updated_since].present?
        begin
          t = Time.iso8601(params[:updated_since])
          products = products.where("products.updated_at > ?", t)
        rescue ArgumentError
          # ignore invalid timestamp
        end
      end

      # Pagination
      page     = params[:page].to_i > 0 ? params[:page].to_i : 1
      per_page = (params[:limit] || 20).to_i
      paginated = products.page(page).per(per_page)

      render json: {
        data:       serialize_products(paginated, is_merchant: is_merchant),
        page:       page,
        isLastPage: paginated.next_page.nil?
      }, status: :ok
    end

    # GET /api/products/:id
    def show
      product = Product.includes(:shop, :category).find(params[:id])
      render json: { product: serialize_product(product) }, status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Product not found" }, status: :not_found
    end

    # POST /api/products
    def create
      shop = current_user.shop
      unless shop
        return render json: { errors: ["Shop not found"] }, status: :unprocessable_entity
      end

      product = shop.products.new(product_params.except(:shop_id))
      product.moderation_status = "pending"

      if product.save
        # moderate immediately
        ModerationService.new(product, current_user).moderate!
        render json: {
          message: "Product created successfully",
          product: serialize_product(product)
        }, status: :created
      else
        render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PUT/PATCH /api/products/:id
    def update
      product = Product.find_by(id: params[:id])
      return render json: { error: "Product not found" }, status: :not_found unless product
      return render json: { error: "Not authorized" },       status: :forbidden unless product.shop.user_id == current_user.id

      if product.update(product_params.except(:shop_id))
        render json: {
          message: "Product updated successfully",
          product: serialize_product(product)
        }, status: :ok
      else
        render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/products/:id
    def destroy
      product = Product.find_by(id: params[:id])
      return render json: { error: "Product not found" }, status: :not_found unless product
      return render json: { error: "Not authorized" },       status: :forbidden unless product.shop.user_id == current_user.id

      product.destroy!
      render json: { message: "Product deleted successfully" }, status: :ok
    rescue ActiveRecord::InvalidForeignKey => e
      render json: {
        error:  "Cannot delete product because it is referenced elsewhere",
        detail: e.message
      }, status: :unprocessable_entity
    end

    private

    def product_params
      params.require(:product).permit(
        :name, :price, :description, :main_image, :category_id,
        :color, :size, :stock, supplementary_images: []
      )
    end

    def guest_limit_reached?
      current_user.nil? && params[:page].to_i > 2
    end

    def merchant_owns_shop?
      current_user&.shop&.id.to_s == params[:shop_id].to_s
    end

    def filter_by_shop(scope)
      if params[:shop_id].present?
        scope.where(shop_id: params[:shop_id])
      else
        scope.order("RANDOM()")
      end
    end

    def serialize_products(products, is_merchant:)
      products.map { |p| serialize_product(p, is_merchant: is_merchant) }
    end

    def serialize_product(product, is_merchant: true)
      data = product.as_json(
        only: [
          :id, :name, :description, :price, :main_image,
          :supplementary_images, :color, :size, :stock,
          :category_id, :shop_id, :views, :created_at
        ],
        include: {
          shop:     { only: [:id, :name, :store_logo_url] },
          category: { only: [:id, :name] }
        }
      )

      if is_merchant
        data.merge!(
          moderation_status:    product.moderation_status,
          moderation_label:     product.moderation_label,
          moderation_confidence: product.moderation_confidence
        )
      end

      data
    end
  end
end
