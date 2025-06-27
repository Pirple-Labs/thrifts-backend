class Api::ShopsController < Api::BaseController
  before_action :set_shop, only: [:show_public, :products_public]

  # POST /api/shops
  def create
    shop = current_user.build_shop(shop_params)

    if shop.save
      render json: { message: "Shop created successfully", shop: shop }, status: :created
    else
      render json: { errors: shop.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/shops/my_shop
  def my_shop
    shop = current_user.shop

    if shop
      render json: { has_shop: true, shop: shop }, status: :ok
    else
      render json: { has_shop: false }, status: :ok
    end
  end

  # GET /api/shops/:id
  def show_public
    render json: {
      id: @shop.id,
      name: @shop.name,
      description: @shop.description,
      store_logo_url: @shop.store_logo_url,
      location: @shop.location,
      created_at: @shop.created_at
    }, status: :ok
  end

  # GET /api/shops/:id/products_public
  def products_public
    products = @shop.products
                    .where("stock > 0") # ✅ Only in-stock
                    .order(created_at: :desc)
                    .includes(:shop)

    render json: products.map { |product|
      {
        id: product.id,
        name: product.name,
        price: product.price,
        description: product.description,
        stock: product.stock,
        main_image: product.main_image,
        supplementary_images: product.supplementary_images,
        shop: {
          id: @shop.id,
          name: @shop.name,
          store_logo_url: @shop.store_logo_url
        }
      }
    }, status: :ok
  end

  private

  def set_shop
    @shop = Shop.find_by(id: params[:id])
    render json: { error: "Shop not found" }, status: :not_found unless @shop
  end

  def shop_params
    {
      name: params[:name],
      description: params[:description],
      phone: params[:phone],
      location: params[:location],
      store_logo_url: params[:store_logo_url],
      pickup_agent: params[:pickup_agent],
      agreed: ActiveModel::Type::Boolean.new.cast(params[:agreed])
    }
  end
end
