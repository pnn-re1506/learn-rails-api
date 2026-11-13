# Routes of the Analysis engine. The main app mounts it at "/analysis", so the real URLs are:
#   GET/POST /analysis/events, GET /analysis/summary
Analysis::Engine.routes.draw do
  resources :events, only: %i[index create]   # -> Analysis::EventsController
  resource  :summary, only: :show             # -> Analysis::SummariesController#show
end
