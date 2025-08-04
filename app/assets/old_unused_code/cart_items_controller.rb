module Api
  class CartItemsController < Api::BaseController
    # `authenticate_user!` is already called in Api::BaseController

    def index
      items = current_user.cart_items.includes(:product)
      render json: { items: items.as_json(include: :product) }
    end

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

    # ✅ NEW: Sync cart items
    def sync
      items = params[:items]

      unless items.is_a?(Array)
        return render json: { success: false, error: "Invalid payload format" }, status: :bad_request
      end

      current_user.cart_items.destroy_all

      new_items = []
      items.each do |item|
        next unless item[:product_id].present? && item[:quantity].to_i > 0

        new_item = current_user.cart_items.create(
          product_id: item[:product_id],
          quantity: item[:quantity]
        )
        new_items << new_item if new_item.persisted?
      end

      render json: {
        success: true,
        items: new_items.map { |i| i.as_json(include: :product) }
      }
    end

    # ✅ NEW: Clear all cart items
    def destroy_all
      current_user.cart_items.destroy_all
      render json: { success: true, message: "Cart cleared" }
    end
  end
end
