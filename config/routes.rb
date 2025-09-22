# config/routes.rb
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
          get :similar_public
        end

        member do
          get :show_public
          get :products_public
        end
      end

      resources :products, only: [:index, :create, :update, :destroy] do
        member do
          post :publish  # NEW: Publish draft products
        end
      end

      # NEW: Product form options for enhanced metadata
      namespace :product_options do
        get 'categories/:category_id', to: 'product_options#category_options'
        get 'specification_fields/:category_id', to: 'product_options#specification_fields'
        get 'brands', to: 'product_options#brands'
      end

      resources :orders, only: [:index] do
        member do
          patch :update_status
        end
      end
    end

    # ────────── 📋 SCHEMAS (Dynamic Product Forms) ──────────
    resources :schemas, only: [:index, :show, :create, :update] do
      collection do
        get :categories  # Get all available categories with schemas
      end
    end

    # ────────── 🛍 PRODUCTS (Buyer-facing) ──────────
    namespace :products do
      resources :products, only: [:index, :show]
    end
    # (Optional alias to support GET /api/products/:id directly)
      get 'products/:id', to: 'products/products#show'

    # ────────── ✅ CATEGORIES ──────────
    get 'categories', to: 'categories/categories#index'

    # ────────── 🤖 RECOMMENDATIONS ──────────
    namespace :recommendations do
      get  'picks',                to: 'picks#index'
      get  ':product_id',          to: 'show#show',     as: :product_recommendations
      post ':product_id/refresh',  to: 'refresh#refresh'
    end

    # ────────── 🔎 MODERATION ──────────
    namespace :moderations do
      post "products/:id", to: "product_moderations#create"
      post "batch",        to: "batch_moderations#create"
    end

    # ────────── 💰 PAYMENTS ──────────
    namespace :payments do
      resources :stk_push, only: :create
      post "callback", to: "daraja_callbacks#create"
      resources :withdrawals, only: [:index, :create]
      get ':id', to: 'payments#show'
    end

    # ────────── 📈 ANALYTICS EVENTS ──────────
        resources :events, only: [:create]
    

    # ────────── 📰 FEEDS (personalised) ──────────
    post "feeds/start", to: "feed#start"  # Api::FeedController#start
    post "feeds/next",  to: "feed#next"   # Api::FeedController#next
    get "feeds/dynamic/:page", to: "feed#dynamic_feed"  # Api::FeedController#dynamic_feed
    
    # ────────── 🏠 PAGE-SPECIFIC LAYOUTS (Playbook-based) ──────────
    get "home/grid", to: "feed#home_grid"  # Api::FeedController#home_grid
    get "pdp/layout", to: "pdp#layout"  # Api::PdpController#layout
    get "wishlist/layout", to: "wishlist#layout"  # Api::WishlistController#layout
    get "checkout/layout", to: "checkout#layout"  # Api::CheckoutController#layout
    get "profile/top-picks", to: "profile#top_picks"  # Api::ProfileController#top_picks
    
    # ────────── 🎯 PLAN DSL (v1.2) ──────────
    post "plan-dsl/start", to: "plan_dsl#start"  # Api::PlanDslController#start
    
    # ────────── 🎮 DEMO ──────────
    get "demo/personalized-feed", to: "demo#personalized_feed"  # Api::DemoController#personalized_feed

    # ────────── 🔧 ADMIN (monitoring & management) ──────────
    namespace :admin do
      resource :metrics, only: [] do
        get :database
        get :business
        get :experiments
        get :costs
        get :performance
        get :slo_status
      end
      
      resources :experiments, param: :key, only: [] do
        patch :status, to: 'metrics#update_experiment_status'
        patch :traffic, to: 'metrics#update_experiment_traffic'
      end
    end
  end
end
