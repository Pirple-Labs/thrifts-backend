Rails.application.routes.draw do
  resources :products, only: [:index, :show, :create, :update, :destroy]
  root "products#index"
end
