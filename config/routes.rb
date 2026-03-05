
Rails.application.routes.draw do
  post "/auth/signup", to: "auth#signup"
  post "/auth/login", to: "auth#login"
  get "/me", to: "auth#me"
end