# app/controllers/api/cart_items_controller.rb
module Api
  class CartItemsController < Api::BaseController
    # `authenticate_user!` is already called in Api::BaseController
    # `current_user` is available from Devise

    def create
      product_id = params.dig(:cart_item, :product_id) || params[:product_id]
      quantity = params.dig(:cart_item, :quantity) || 1

      item = current_user.cart_items.new(product_id: product_id, quantity: quantity)

      if item.save
        render json: { success: true, item: item.as_json(include: :product) }
      else
        render json: { success: false, errors: item.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      item = current_user.cart_items.find_by(product_id: params[:product_id])

      if item&.destroy
        render json: { success: true }
      else
        render json: { success: false, error: "Cart item not found" }, status: :not_found
      end
    end
  end
end
