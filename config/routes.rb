Rails.application.routes.draw do
  root "auth#health"
  get "/health", to: "auth#health"

  post "/auth/signup", to: "auth#signup"
  post "/auth/login", to: "auth#login"
  get "/me", to: "auth#me"

  resources :grounds
  resources :slots
  resources :bookings
end