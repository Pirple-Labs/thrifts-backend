# app/controllers/api/categories/categories_controller.rb

module Api
  module Categories
    class CategoriesController < Api::BaseController
      skip_before_action :authenticate_user!

      def index
        categories = Category.all.order(:name)
        render json: categories
      end
    end
  end
end
