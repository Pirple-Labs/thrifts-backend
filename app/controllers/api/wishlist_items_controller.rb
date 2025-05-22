# app/controllers/api/wishlist_items_controller.rb
module Api
  class WishlistItemsController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user!
    before_action :authenticate_api_user!

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

    private

    def authenticate_api_user!
      token = request.headers['Authorization']&.split&.last

      if token.blank?
        render json: { error: 'Unauthorized: Token missing' }, status: :unauthorized and return
      end

      begin
        payload, = JWT.decode(token, Rails.application.credentials.secret_key_base, true, algorithm: 'HS256')
        @current_user = User.find_by(id: payload['user_id'])

        unless @current_user
          render json: { error: 'Unauthorized: User not found' }, status: :unauthorized
        end
      rescue JWT::DecodeError => e
        render json: { error: "Unauthorized: Invalid token (#{e.message})" }, status: :unauthorized
      end
    end
    

    def current_user
      @current_user
    end
  end
end
