# config/routes.rb

Rails.application.routes.draw do
  # ────────── 🔐 AUTH ──────────
  namespace :api do
    namespace :auth do
      post :manual_login
      post :google_login
      post :signup
    end
  end

  # ────────── 👤 USERS ──────────
  namespace :api do
    namespace :users do
      resource :profile, only: [:update]

      resources :wishlist_items, only: [:index, :create] do
        collection do
          post :sync
          delete :destroy
        end
      end

      resources :cart_items, only: [:index, :create] do
        collection do
          post :sync
          delete :destroy
          delete :destroy_all
        end
      end

      resources :delivery_addresses, only: [:index, :create, :destroy]

      resources :orders, only: [:index, :create] do
        member do
          put :mark_picked_up
        end
      end
    end
  end

  # ────────── 🏪 MERCHANTS ──────────
  namespace :api do
    namespace :merchants do
      resource :shop, only: [:create] do
        get :my_shop, on: :collection
        get :show_public, on: :member
        get :products_public, on: :member
      end

      resources :products, only: [:create, :update, :destroy]

      resources :orders, only: [:index] do
        member do
          patch :update_status
        end
      end
    end
  end

  # ────────── 🛍 PRODUCTS (Buyer‑facing) ──────────
  namespace :api do
    namespace :products do
      resources :products, only: [:index, :show]
    end
  end

  # ────────── ✅ CATEGORIES ──────────
  namespace :api do
    namespace :categories do
      get '/', to: 'categories#index'
    end
  end

  # ────────── 🤖 RECOMMENDATIONS ──────────
  namespace :api do
    namespace :recommendations, param: :product_id do
      get   ':product_id',         to: 'show#show'
      post  ':product_id/refresh', to: 'refresh#refresh'
    end

    namespace :recommendations do
      get 'picks', to: 'picks#index'
    end
  end

  # ────────── 🔎 MODERATION ──────────
  namespace :moderations do
    post 'products/:id', to: 'product_moderations#create'
  end
end
