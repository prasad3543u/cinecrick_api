Rails.application.routes.draw do
  get "/", to: "auth#health"

  post "/auth/signup", to: "auth#signup"
  post "/auth/login", to: "auth#login"
  get "/me", to: "auth#me"
  patch "/me/update", to: "auth#update_profile"
  patch "/me/change_password", to: "auth#change_password"
  delete "/me/delete", to: "auth#delete_account"
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

  get "/admin/bookings", to: "bookings#admin_index"
  get "/admin/stats", to: "admin#stats"
  post "/admin/block_date", to: "admin#block_date"
  delete "/admin/unblock_date", to: "admin#unblock_date"
  get "/admin/blocked_dates", to: "admin#blocked_dates"
  get "/admin/users", to: "admin#users"
  patch "/admin/users/:id/update_role", to: "admin#update_role"
end