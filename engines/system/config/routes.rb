# Routes of the System engine. The main app mounts it at "/system", so the real URLs are:
#   POST /system/signup, POST /system/login, GET /system/me
System::Engine.routes.draw do
  # --- Authentication (no token required) ---
  post "signup", to: "users#create"       # -> System::UsersController#create
  post "login",  to: "sessions#create"    # -> System::SessionsController#create

  # --- Token required ---
  get "me", to: "users#me"                # Current user's info
end
