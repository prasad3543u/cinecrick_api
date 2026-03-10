Rails.application.routes.draw do
  get "/", to: "auth#health"

  post "/auth/signup", to: "auth#signup"
  post "/auth/login", to: "auth#login"
  post "/grounds/:id/generate_slots", to: "grounds#generate_slots"
  get "/me", to: "auth#me"
  get "/make_admin", to: "auth#make_admin"
  resources :grounds do
    post :generate_slots, on: :member
  end

  resources :slots

  resources :bookings, only: [:index, :create] do
    member do
      patch :confirm
      patch :cancel
    end
  end
end