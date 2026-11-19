# Routes of the Website engine. The main app mounts it at "/website", so the real URLs are:
#   GET/POST /website/sites, GET/PATCH/DELETE /website/sites/:id
#   GET/POST /website/sites/:site_id/members, PATCH/DELETE /website/sites/:site_id/members/:user_id
Website::Engine.routes.draw do
  resources :sites, only: %i[index show create update destroy] do   # -> Website::SitesController
    resources :members, only: %i[index create update destroy], param: :user_id   # -> Website::MembersController
  end
end
