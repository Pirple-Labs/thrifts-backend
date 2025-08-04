module Api
  module Merchants
    class ProductsController < Api::BaseController

    def index
        shop = current_user.shop
        return render json: { error: "Shop not found" }, status: :not_found unless shop

        products = shop.products.order(created_at: :desc)

        render json: {
            success: true,
            products: products.map { |p| serialize_product(p) }
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
            product: product
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
            product: product
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
          :name, :price, :description, :main_image, :category_id,
          :color, :size, :stock, supplementary_images: []
        )
      end

      def serialize_product(product)
        product.as_json(only: [
            :id, :name, :price, :stock, :main_image, :moderation_status, :created_at
        ])
     end
    end
  end
end
