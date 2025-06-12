# app/controllers/api/wishlist_items_controller.rb
module Api
  class WishlistItemsController < Api::BaseController
    # No need to repeat `authenticate_user!` — it's inherited from Api::BaseController

    def create
      item = current_user.wishlist_items.new(product_id: params[:product_id])

      if item.save
        render json: { success: true, wishlist_item: item }
      else
        render json: { success: false, errors: item.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      item = current_user.wishlist_items.find_by(product_id: params[:product_id])

      if item&.destroy
        render json: { success: true }
      else
        render json: { success: false, error: "Wishlist item not found" }, status: :not_found
      end
    end
  end
end
