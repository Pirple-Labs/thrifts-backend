class ApplicationController < ActionController::Base
  # Protect from CSRF (skip for APIs)
  protect_from_forgery with: :exception

  before_action :authenticate_user!

  # Optional: helper for web views
  def current_user
    super
  end
end
