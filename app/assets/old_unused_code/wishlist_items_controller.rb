# app/controllers/api/wishlist_items_controller.rb
module Api
  class WishlistItemsController < Api::BaseController
    # No need to repeat `authenticate_user!` — it's inherited from Api::BaseController
    def index
      items = current_user.wishlist_items.includes(:product)
      render json: { items: items.as_json(include: :product) }
    end

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
    def sync
  product_ids = params[:items] || []

  # Remove wishlist items not in the new list
  current_user.wishlist_items.where.not(product_id: product_ids).destroy_all

  # Add missing items (skip duplicates)
  existing_ids = current_user.wishlist_items.pluck(:product_id)
  new_ids = product_ids - existing_ids
  new_ids.each do |pid|
    current_user.wishlist_items.create(product_id: pid)
  end

  render json: { success: true, message: "Wishlist synced" }
end

  end
end
