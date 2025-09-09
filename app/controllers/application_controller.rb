# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  # For API-only apps you can use :null_session (prevents CSRF exceptions on JSON)
  protect_from_forgery with: :null_session

  before_action :authenticate_user!
end
