class ProductsController < ApplicationController
    before_action :set_product, only: [:show, :update, :destroy]
  
    # GET /products
    def index
      products = Product.all
      render json: products
    end
  
    # GET /products/:id
    def show
      render json: @product
    end
  
    # POST /products
    def create
      product = Product.new(product_params)
      if product.save
        render json: product, status: :created
      else
        render json: product.errors, status: :unprocessable_entity
      end
    end
  
    # PUT /products/:id
    def update
      if @product.update(product_params)
        render json: @product
      else
        render json: @product.errors, status: :unprocessable_entity
      end
    end
  
    # DELETE /products/:id
    def destroy
      @product.destroy
      head :no_content
    end
  
    private
  
    def set_product
      @product = Product.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Product not found' }, status: :not_found
    end
  
    def product_params
      params.require(:product).permit(:name, :store_logo, :product_image, :price, :description)
    end
  end
  