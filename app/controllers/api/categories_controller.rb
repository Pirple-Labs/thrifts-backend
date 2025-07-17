module Api
  class CategoriesController < Api::BaseController
    skip_before_action :authenticate_user!  # 👈 Skip auth just for this controller

    def index
      categories = Category.all.order(:name)
      render json: categories
    end
  end
end
