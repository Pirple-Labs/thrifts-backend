Rails.application.routes.draw do
  # Devise routes for standard authentication (email/password)
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }

  # API Namespace
  namespace :api do
    # Google OAuth authentication
    post 'auth/manual_login', to: 'auth#manual_login'
    post 'auth/google_login', to: 'auth#google_login'
    # Sign-up route for manual email/password sign-up
    post 'auth/signup', to: 'auth#signup'
  end

  # Product Routes
  resources :products, only: [:index]
end
