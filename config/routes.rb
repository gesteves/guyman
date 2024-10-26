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
  resources :playlists, only: [:index, :destroy] do
    member do
      post :toggle_follow
      post :toggle_lock
      post :regenerate
      post :regenerate_cover
      get :redirect_to_spotify
    end

    collection do
      get 'page/:page', to: 'playlists#index'
    end
  end
  resources :music_requests, only: [:index, :create, :destroy] do
    member do
      patch :activate
    end

    collection do
      get 'page/:page', to: 'music_requests#index'
    end
  end
  resources :tracks, only: [:index, :destroy]

  get "/settings", to: "preferences#edit", as: :settings

  #PWA
  get    '/service_worker.js'               => 'service_worker#index', defaults: { format: 'js' }, :as => :service_worker
  get    '/manifest.json'                   => 'manifest#index', :as => :manifest
  post   '/push-notifications/subscription' => 'push_subscriptions#create', :as => :push_subscribe
  delete '/push-notifications/subscription' => 'push_subscriptions#destroy'

  # Defines the root path route ("/")
  root "home#index"
end
