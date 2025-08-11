Rails.application.routes.draw do
  devise_for :users, defaults: { format: :json }

  namespace :api do

    # ────────── 🔐 AUTH ──────────
    namespace :auth do
      post :manual_login, to: 'auth#manual_login'
      post :google_login, to: 'auth#google_login'
      post :signup,       to: 'auth#signup'
    end

    # ────────── 👤 USERS ──────────
    namespace :users do
      resource  :profile, only: [:update]

      resources :wishlist_items, only: [:index, :create] do
        collection do
          post   :sync
          delete :destroy
        end
      end

      resources :cart_items, only: [:index, :create] do
        collection do
          post   :sync
          delete :destroy
          delete :destroy_all
        end
      end

      resources :delivery_addresses, only: [:index, :create, :destroy]

      resources :orders, only: [:index, :create, :show] do
        member do
          put :mark_picked_up
        end
      end
    end

    # ────────── 🏪 MERCHANTS ──────────
    namespace :merchants do
      resource :shop, only: [:create] do
        collection do
          get :my_shop
        end

        member do
          get :show_public
          get :products_public
        end
      end

      resources :products, only: [:index, :create, :update, :destroy]

      resources :orders, only: [:index] do
        member do
          patch :update_status
        end
      end
    end

    # ────────── 🛍 PRODUCTS (Buyer-facing) ──────────
    namespace :products do
      resources :products, only: [:index, :show]
    end

    # ────────── ✅ CATEGORIES ──────────
    get 'categories', to: 'categories/categories#index'

    # ────────── 🤖 RECOMMENDATIONS ──────────
    namespace :recommendations do
      get  'picks',                to: 'picks#index'
      get  ':product_id',         to: 'show#show',     as: :product_recommendations
      post ':product_id/refresh', to: 'refresh#refresh'
    end

    # ────────── 🔎 MODERATION ──────────
    namespace :moderations do
      post "products/:id", to: "product_moderations#create"
      post "batch",        to: "batch_moderations#create"
    end

    # ────────── 💰 PAYMENTS ──────────
    namespace :payments do
      # Initiate STK push
      resources :stk_push, only: :create

      # Single, unambiguous STK callback endpoint
      # Make MPESA_CALLBACK_URL point to: https://<public-host>/api/payments/callback
       post "callback", to: "daraja_callbacks#create"

      # Withdrawals
      resources :withdrawals, only: [:index, :create]
    end
    # inside namespace :api do
    namespace :payments do
      get ':id', to: 'payments#show'
    end


  end
end
