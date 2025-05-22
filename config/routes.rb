Rails.application.routes.draw do
  # Devise routes for standard authentication (email/password)
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }

  # API Namespace
 namespace :api, defaults: { format: :json } do

    # Google OAuth & manual login
    post 'auth/manual_login', to: 'auth#manual_login'
    post 'auth/google_login', to: 'auth#google_login'
    post 'auth/signup', to: 'auth#signup'

    # 🛍️ Shop creation route
    resources :shops, only: [:create]
    resources :products, only: [:index]
    resources :wishlist_items, only: [:create]
    delete 'wishlist_items', to: 'wishlist_items#destroy'

  end

  # Product Routes (legacy, not namespaced)
  
end
