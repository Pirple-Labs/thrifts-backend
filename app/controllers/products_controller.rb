class ProductsController < ApplicationController
  before_action :set_json_format

  def index
    products = Product.all
    render json: products, status: :ok
  end

  private

  def set_json_format
    request.format = :json if request.format.html?
  end
end
