class ProductsController < ApplicationController
  before_action :set_json_format

  def index
    products = Product.page(params[:page]).per(params[:limit])
    render json: products
  end
  

  private

  def set_json_format
    request.format = :json if request.format.html?
  end
end
