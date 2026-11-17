# Routes of the Website engine. The main app mounts it at "/website", so the real URLs are:
#   GET/POST /website/sites, GET /website/sites/:id
Website::Engine.routes.draw do
  resources :sites, only: %i[index show create]   # -> Website::SitesController
end
