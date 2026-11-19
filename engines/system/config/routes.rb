# Routes of the System engine. The main app mounts it at "/system", so the real URLs are:
#   POST /system/signup, POST /system/login, GET /system/me, GET /system/users, PATCH /system/users/:id
System::Engine.routes.draw do
  # --- Authentication (no token required) ---
  post "signup", to: "users#create"       # -> System::UsersController#create
  post "login",  to: "sessions#create"    # -> System::SessionsController#create

  # --- Token required ---
  get "me", to: "users#me"                # Current user's info

  # --- Token required + admin role ---
  resources :users, only: %i[index update]   # List users, change a user's role
end
