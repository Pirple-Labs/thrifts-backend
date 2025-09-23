module Api
  module Merchants
    class ProductsController < Api::BaseController

      def index
        shop = current_user.shop
        return render json: { error: "Shop not found" }, status: :not_found unless shop

        # 🔢 Pagination params
        page = params[:page].to_i.clamp(1, 100)
        limit = params[:limit].to_i.clamp(1, 50)
        offset = (page - 1) * limit

        # 🛍 Fetch paginated products
        products = shop.products
                       .includes(:category) # eager load category to avoid N+1
                       .order(created_at: :desc)
                       .offset(offset)
                       .limit(limit)

        total_count = shop.products.count
        total_pages = (total_count / limit.to_f).ceil

        render json: {
          success: true,
          products: products.map { |p| serialize_product(p) },
          pagination: {
            current_page: page,
            per_page: limit,
            total_count: total_count,
            total_pages: total_pages
          }
        }
      end

      def create
        shop = current_user.shop
        return render json: { errors: ["Shop not found"] }, status: :unprocessable_entity unless shop

        # Handle schema-based product creation
        if params[:schema_version].present?
          return create_schema_product(shop)
        else
          return create_legacy_product(shop)
        end
      end

      def update
        product = Product.find_by(id: params[:id])
        return render json: { error: "Product not found" }, status: :not_found unless product
        return render json: { error: "Not authorized" }, status: :forbidden unless product.shop.user_id == current_user.id

        if product.update(product_params.except(:shop_id))
          render json: {
            message: "Product updated successfully",
            product: serialize_product(product)
          }, status: :ok
        else
          render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        product = Product.find_by(id: params[:id])
        return render json: { error: "Product not found" }, status: :not_found unless product
        return render json: { error: "Not authorized" }, status: :forbidden unless product.shop.user_id == current_user.id

        product.destroy!
        render json: { message: "Product deleted successfully" }, status: :ok
      rescue ActiveRecord::InvalidForeignKey => e
        render json: {
          error: "Cannot delete product because it is referenced elsewhere",
          detail: e.message
        }, status: :unprocessable_entity
      end

      # POST /api/merchants/products/:id/publish
      def publish
        product = Product.find_by(id: params[:id])
        return render json: { error: "Product not found" }, status: :not_found unless product
        return render json: { error: "Not authorized" }, status: :forbidden unless product.shop.user_id == current_user.id

        if product.publish!
          render json: {
            message: "Product published successfully",
            product: serialize_product(product)
          }, status: :ok
        else
          validation_errors = product.schema_validation_errors
          render json: {
            error: "Cannot publish product",
            validation_errors: validation_errors
          }, status: :unprocessable_entity
        end
      end

      private

      def create_schema_product(shop)
        # Validate schema exists
        schema = Schema.find_by(id: params[:schema_version])
        return render json: { error: "Schema not found" }, status: :not_found unless schema

        # Create product with schema attributes
        product = shop.products.new(
          name: params[:name],
          price: params[:price],
          description: params[:description],
          main_image: params[:main_image],
          category_id: params[:category_id],
          stock: params[:stock] || 1,
          schema_version: params[:schema_version],
          status: 'draft',
          schema_attributes: params[:attributes] || {}
        )

        if product.save
          # Moderate images if provided
          if product.main_image.present?
            ModerationService.new(product, product.main_image, user_id: current_user.id).call
          end

          render json: {
            message: "Product created successfully as draft",
            product: serialize_product(product),
            can_publish: product.can_publish?,
            validation_errors: product.schema_validation_errors
          }, status: :created
        else
          render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def create_legacy_product(shop)
        # Original legacy product creation
        product = shop.products.new(product_params.except(:shop_id))
        product.moderation_status = "pending"
        product.status = 'published' # Legacy products are published immediately

        if product.save
          ModerationService.new(product, product.main_image, user_id: current_user.id).call
          render json: {
            message: "Product created successfully",
            product: serialize_product(product)
          }, status: :created
        else
          render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def product_params
        params.require(:product).permit(
          :name,
          :price,
          :description,
          :main_image,
          :category_id,
          :color,
          :size,
          :stock,
          :moderation_status,          # allow for override (e.g., approved)
          :subcategory,               # NEW: More specific category
          :material,                  # NEW: What it's made of
          :style,                     # NEW: Design aesthetic
          :use_case,                  # NEW: How it's used
          :seasonality,               # NEW: When it's appropriate
          :brand_id,                  # NEW: Brand selection
          supplementary_images: [],   # handle multiple supplementary images
          specifications: {}          # NEW: Technical details (JSON)
        )
      end

      def serialize_product(product)
        base_data = {
          id: product.id,
          name: product.name,
          price: product.price,
          stock: product.stock,
          main_image: product.main_image,
          moderation_status: product.moderation_status,
          category_id: product.category_id,
          created_at: product.created_at,
          category_name: product.category&.name,
          brand_name: product.brand&.name,
          brand_category: product.brand&.category,
          brand_specialization: product.brand&.specialization
        }

        # Add schema-specific fields
        if product.schema_product?
          base_data.merge!(
            schema_version: product.schema_version,
            status: product.status,
            attributes: product.schema_attributes,
            can_publish: product.can_publish?,
            validation_errors: product.schema_validation_errors
          )
        else
          # Legacy product fields
          base_data.merge!(
            subcategory: product.subcategory,
            material: product.material,
            style: product.style,
            use_case: product.use_case,
            seasonality: product.seasonality,
            brand_id: product.brand_id,
            specifications: product.specifications
          )
        end

        base_data
      end
    end
  end
end
