module Api
  module Merchants
    class ProductsController < Api::BaseController

      def index
        shop = current_user.shop
        return render json: { error: "Shop not found" }, status: :not_found unless shop

        # 🔢 Pagination params
        page = params[:page].to_i.clamp(1, 100)
        limit = params[:limit].to_i.clamp(1, 50)
        offset = (page - 1) * limit

        # 🛍 Fetch paginated products
        products = shop.products
                       .includes(:category) # eager load category to avoid N+1
                       .order(created_at: :desc)
                       .offset(offset)
                       .limit(limit)

        total_count = shop.products.count
        total_pages = (total_count / limit.to_f).ceil

        render json: {
          success: true,
          products: products.map { |p| serialize_product(p) },
          pagination: {
            current_page: page,
            per_page: limit,
            total_count: total_count,
            total_pages: total_pages
          }
        }
      end

      def create
        shop = current_user.shop
        return render json: { errors: ["Shop not found"] }, status: :unprocessable_entity unless shop

        product = shop.products.new(product_params.except(:shop_id))
        product.moderation_status = "pending"

        if product.save
          ModerationService.new(product, product.main_image, user_id: current_user.id).call
          render json: {
            message: "Product created successfully",
            product: serialize_product(product)
          }, status: :created
        else
          render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        product = Product.find_by(id: params[:id])
        return render json: { error: "Product not found" }, status: :not_found unless product
        return render json: { error: "Not authorized" }, status: :forbidden unless product.shop.user_id == current_user.id

        if product.update(product_params.except(:shop_id))
          render json: {
            message: "Product updated successfully",
            product: serialize_product(product)
          }, status: :ok
        else
          render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        product = Product.find_by(id: params[:id])
        return render json: { error: "Product not found" }, status: :not_found unless product
        return render json: { error: "Not authorized" }, status: :forbidden unless product.shop.user_id == current_user.id

        product.destroy!
        render json: { message: "Product deleted successfully" }, status: :ok
      rescue ActiveRecord::InvalidForeignKey => e
        render json: {
          error: "Cannot delete product because it is referenced elsewhere",
          detail: e.message
        }, status: :unprocessable_entity
      end

      private

      def product_params
        params.require(:product).permit(
          :name,
          :price,
          :description,
          :main_image,
          :category_id,
          :color,
          :size,
          :stock,
          :moderation_status,          # allow for override (e.g., approved)
          supplementary_images: []     # handle multiple supplementary images
        )
      end

      def serialize_product(product)
        product.as_json(
          only: [
            :id,
            :name,
            :price,
            :stock,
            :main_image,
            :moderation_status,
            :category_id,
            :created_at
          ]
        ).merge(
          category_name: product.category&.name
        )
      end
    end
  end
end
