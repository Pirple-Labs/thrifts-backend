# app/controllers/api/base_controller.rb
module Api
  class BaseController < ActionController::API
    before_action :authenticate_user!  # ✅ Keep this if you want JWT auth
  end
end
