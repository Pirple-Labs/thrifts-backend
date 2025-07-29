class ApplicationController < ActionController::Base
  # Skip CSRF for now (or leave commented)
  # protect_from_forgery with: :exception

  before_action :authenticate_user!

  def current_user
    super
  end
end
