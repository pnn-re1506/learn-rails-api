# Routes of the Report engine. The main app mounts it at "/report", so the real URLs are:
#   GET/POST /report/snapshots, GET/DELETE /report/snapshots/:id
Report::Engine.routes.draw do
  resources :snapshots, only: %i[index show create destroy]   # -> Report::SnapshotsController
end
