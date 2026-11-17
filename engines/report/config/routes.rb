# Routes of the Report engine. The main app mounts it at "/report", so the real URLs are:
#   GET/POST /report/details                 raw statistics rows (only Report's own data)
#   GET /report/reports/via_join             final report, website data merged by a cross-database SQL JOIN
#   GET /report/reports/via_service          final report, website data merged in Ruby via Website::SiteService
Report::Engine.routes.draw do
  resources :details, only: %i[index create]   # -> Report::DetailsController

  get "reports/via_join",    to: "reports#via_join"
  get "reports/via_service", to: "reports#via_service"
end
