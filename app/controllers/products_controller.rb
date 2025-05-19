class ProductsController < ApplicationController
  before_action :set_json_format

  def index
    # Randomize the products order using "RANDOM()"
    products = Product.order("RANDOM()").page(params[:page]).per(params[:limit])

    # Render the products as JSON
    render json: products
  end

  private

  def set_json_format
    request.format = :json if request.format.html?
  end
end
