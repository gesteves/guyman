Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  devise_scope :user do
    get "/sign-in" => "users/sessions#new", as: :new_user_session
    delete "/sign-out" => "devise/sessions#destroy", as: :destroy_user_session
  end

  require 'sidekiq/web'
  require 'sidekiq-scheduler/web'
  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  resource :preference, only: [:update]
  resources :playlists, only: [:index, :show] do
    member do
      post :lock
      post :regenerate
    end

    collection do
      post :regenerate_all, to: 'playlists#regenerate_all'
    end
  end

  get "/settings", to: "preferences#edit", as: :settings
  # Defines the root path route ("/")
  root "home#index"
end
