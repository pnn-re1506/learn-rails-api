Rails.application.routes.draw do
  get "up" => "rails/health#show"              # Health check

  # The main app is only the "entry gate": it mounts each engine under a URL prefix.
  # Detailed routes live in engines/<name>/config/routes.rb
  mount System::Engine   => "/system"          # /system/signup, /system/login, /system/me
  mount Website::Engine  => "/website"         # /website/sites
  mount Report::Engine   => "/report"          # /report/details, /report/reports/...
end
