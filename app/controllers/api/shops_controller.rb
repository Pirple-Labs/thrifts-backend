class Api::ShopsController < ApplicationController
    before_action :authenticate_user!
  
    # POST /api/shops
    def create
      shop = current_user.shops.build(shop_params)
  
      if shop.save
        # Upgrade user to merchant role if not already
        current_user.update(role: :merchant) unless current_user.merchant?
  
        render json: { success: true, shop: shop, role: current_user.role }, status: :created
      else
        render json: { success: false, errors: shop.errors.full_messages }, status: :unprocessable_entity
      end
    end
  
    private
  
    def shop_params
      params.require(:shop).permit(:name, :description)
    end
  end
  