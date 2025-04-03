Rails.application.routes.draw do
  # Devise routes for standard authentication (email/password)
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }

  # API Namespace
  namespace :api do
    # Google OAuth authentication
    post "auth/google_login", to: "auth#google_login"  # ✅ Updated route name for clarity
  end

  # Product Routes
  resources :products, only: [:index]
end
