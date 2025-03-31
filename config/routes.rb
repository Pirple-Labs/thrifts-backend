Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }

  namespace :api do
    post "auth/google", to: "auth#google"  # ✅ Add this line for Google Auth
  end

  resources :products, only: [:index]
end
