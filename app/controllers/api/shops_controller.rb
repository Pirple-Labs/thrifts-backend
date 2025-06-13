class Api::ShopsController < Api::BaseController
  # POST /api/shops
  def create
    shop = current_user.shops.new(shop_params)

    if shop.save
      render json: { message: "Shop created successfully", shop: shop }, status: :created
    else
      render json: { errors: shop.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def shop_params
    {
      name: params[:name],
      description: params[:description],
      phone: params[:phone],
      location: params[:location],
      store_logo_url: params[:store_logo_url], # ✅ matches frontend key
      pickup_agent: params[:pickup_agent],
      agreed: ActiveModel::Type::Boolean.new.cast(params[:agreed]) # ✅ ensures true/false
    }
  end
end
