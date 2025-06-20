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
   # GET /api/shops/my_shop
  def my_shop
    shop = current_user.shops.first

    if shop
      render json: { has_shop: true, shop: shop }, status: :ok
    else
      render json: { has_shop: false }, status: :ok
    end
  end

  # GET /api/shops/:id
def show_public
  shop = Shop.find_by(id: params[:id])

  if shop
    render json: {
      id: shop.id,
      name: shop.name,
      description: shop.description,
      store_logo_url: shop.store_logo_url,
      location: shop.location,
      created_at: shop.created_at
    }, status: :ok
  else
    render json: { error: "Shop not found" }, status: :not_found
  end
end

  # GET /api/shops/:id/products
def products
  shop = Shop.find_by(id: params[:id])

  if shop
    products = shop.products.order(created_at: :desc) # Add pagination later if needed

    render json: products.as_json(only: [:id, :name, :price, :description, :images]), status: :ok
  else
    render json: { error: "Shop not found" }, status: :not_found
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
