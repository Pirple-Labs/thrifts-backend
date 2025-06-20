Rails.application.routes.draw do
  # Devise routes for standard authentication (email/password)
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }

  # API Namespace
  namespace :api, defaults: { format: :json } do
    # 🔐 Authentication routes
    post 'auth/manual_login', to: 'auth#manual_login'
    post 'auth/google_login', to: 'auth#google_login'
    post 'auth/signup', to: 'auth#signup'

    # 🛍️ Shop & Product routes
    resources :shops, only: [:create]
    get 'shops/my_shop', to: 'shops#my_shop'
    resources :products, only: [:index, :create]

    # 🧾 Buyer-facing shop view
    get 'shops/:id', to: 'shops#show_public'
    get 'shops/:id/products', to: 'shops#products'

    # 💖 Wishlist routes
    resources :wishlist_items, only: [:index, :create]
    delete 'wishlist_items', to: 'wishlist_items#destroy'
    post 'wishlist_items/sync', to: 'wishlist_items#sync'         # <-- ✅ NEW

    # 🛒 Cart routes
    resources :cart_items, only: [:index, :create]
    delete 'cart_items', to: 'cart_items#destroy'
    delete 'cart_items/destroy_all', to: 'cart_items#destroy_all'
    post 'cart_items/sync', to: 'cart_items#sync'                 # <-- ✅ NEW
  end
end
