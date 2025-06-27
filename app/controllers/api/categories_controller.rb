module Api
  class CategoriesController < Api::BaseController
    def index
      categories = Category.all.order(:name)
      render json: categories
    end
  end
end
