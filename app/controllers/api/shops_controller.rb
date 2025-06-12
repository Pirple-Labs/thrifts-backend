class Api::ShopsController < Api::BaseController
   # POST /api/shops
    def create
  shop = current_user.shops.new(
    name: params[:name],
     phone: params[:phone],
    location: params[:location],
    image_url: params[:shopImage],
    description: params[:description],   # assuming same as shop description
    pickup_agent: params[:pickupAgent],
    agreed: params[:agreed]
  )

  if shop.save
    render json: { message: "Shop created successfully", shop: shop }, status: :created
  else
    render json: { errors: shop.errors.full_messages }, status: :unprocessable_entity
  end
end

  
    private
  
    def shop_params
       params.permit(
          :name,
          :description,
          :phone,
          :location,
          :shopImage,
          :price,
          :pickupAgent,
          :agreed,
          itemImages: []
        )
end
  end
  