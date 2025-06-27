Rails.application.routes.draw do
  # Devise routes for standard authentication
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }

  # API Namespace
  namespace :api, defaults: { format: :json } do
    # ✅ Categories
    resources :categories, only: [:index]

    # 🔐 Auth
    post 'auth/manual_login', to: 'auth#manual_login'
    post 'auth/google_login', to: 'auth#google_login'
    post 'auth/signup', to: 'auth#signup'

    # 🏪 Shops
    resources :shops, only: [:create] do
      collection do
        get :my_shop                      # /api/shops/my_shop
      end
      member do
        get :show_public                 # /api/shops/:id/show_public
        get :products_public             # /api/shops/:id/products_public
      end
    end

    # 🛍️ Products (merchant/internal use)
    resources :products, only: [:index, :create]

    # 💖 Wishlist
    resources :wishlist_items, only: [:index, :create]
    delete 'wishlist_items', to: 'wishlist_items#destroy'
    post 'wishlist_items/sync', to: 'wishlist_items#sync'

    # 🛒 Cart
    resources :cart_items, only: [:index, :create]
    delete 'cart_items', to: 'cart_items#destroy'
    delete 'cart_items/destroy_all', to: 'cart_items#destroy_all'
    post 'cart_items/sync', to: 'cart_items#sync'

    # ⭐️ Picks
    get 'picks', to: 'recommended_products#index'

    # 📦 Orders (Customer-facing)
    resources :orders, only: [:index]

    # 📍 Delivery Addresses
    resources :delivery_addresses, only: [:index, :create, :destroy]

    # 📦 Merchant Orders
    namespace :merchant do
      resources :orders, only: [:index] do
        member do
          patch :update_status
        end
      end
    end
  end
end
