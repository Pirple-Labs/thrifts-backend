module Api
  module Merchants
    class ShopsController < Api::BaseController
      skip_before_action :authenticate_user!, only: [:similar_public], raise: false
      before_action :set_shop, only: [:show_public, :products_public]

      # POST /api/merchants/shop
      def create
        shop = current_user.build_shop(shop_params)

        if shop.save
          render json: { message: "Shop created successfully", shop: shop }, status: :created
        else
          render json: { errors: shop.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/merchants/shop/my_shop
      def my_shop
        shop = current_user.shop

        if shop
          render json: { has_shop: true, shop: shop }, status: :ok
        else
          render json: { has_shop: false }, status: :ok
        end
      end

      # GET /api/merchants/shop/:id/show_public
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

      # GET /api/merchants/shop/:id/products_public
      def products_public
        products = @shop.products
                        .where("stock > 0")
                        .where(moderation_status: "approved")
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

      # GET /api/merchants/shop/similar_public
      def similar_public
        # Validate required parameters
        shop_id = params[:id]
        product_id = params[:product_id]
        limit = [params[:limit]&.to_i || 4, 20].min # Cap at 20
        page = [params[:page]&.to_i || 1, 1].max
        offset = (page - 1) * limit

        # Validate shop exists
        shop = Shop.find_by(id: shop_id)
        unless shop
          return render json: { error: "Shop not found" }, status: :not_found
        end

        # Validate product exists and belongs to shop
        target_product = Product.find_by(id: product_id, shop_id: shop_id)
        unless target_product
          return render json: { error: "Product not found in this shop" }, status: :not_found
        end

        # Get target category and brand
        target_category = params[:category_id]&.to_i || target_product.category_id
        target_brand = params[:brand].presence || target_product.brand&.name

        # Base query: products from same shop, excluding target product
        base_products = Product.where(shop_id: shop_id)
                              .where.not(id: product_id)
                              .where("stock > 0")
                              .where(moderation_status: "approved")
                              .includes(:shop, :brand, :category)

        # Primary: same category
        primary_products = base_products.where(category_id: target_category) if target_category

        # Secondary: same brand (if present)
        if target_brand.present? && primary_products
          primary_products = primary_products.joins(:brand).where(brands: { name: target_brand })
        end

        # Order by recent first, then by views
        ordered_products = (primary_products || base_products)
                          .order(created_at: :desc, views: :desc)
                          .limit(limit)

        # Backfill if needed
        if ordered_products.size < limit
          remaining_limit = limit - ordered_products.size
          excluded_ids = ordered_products.pluck(:id)
          
          backfill_products = base_products
                             .where.not(id: excluded_ids)
                             .order(created_at: :desc, views: :desc)
                             .limit(remaining_limit)
          
          ordered_products = ordered_products.to_a + backfill_products.to_a
        end

        # Apply pagination
        paginated_products = ordered_products[offset, limit] || []
        total_count = base_products.count

        # Build response
        products_data = paginated_products.map do |product|
          {
            id: product.id,
            name: product.name,
            price: product.price,
            image_url: product.main_image,
            shop: {
              id: product.shop.id,
              name: product.shop.name,
              store_logo_url: product.shop.store_logo_url
            },
            brand: product.brand&.name,
            category_id: product.category_id
          }
        end

        # Determine if there are more pages
        has_more = (offset + limit) < total_count

        render json: {
          products: products_data,
          page: page,
          limit: limit,
          hasMore: has_more,
          total: total_count
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
  end
end
