Rails.application.routes.draw do
  get "up" => "rails/health#show"              # Health check

  get "api-docs"              => "docs#show"   # Swagger UI
  get "api-docs/openapi.yml"  => "docs#spec"   # OpenAPI file (config/openapi.yml)

  # The main app is only the "entry gate": it mounts each engine under a URL prefix.
  # Detailed routes live in engines/<name>/config/routes.rb
  mount System::Engine  => "/system"  if ENV.fetch("ENABLE_SYSTEM", "1") == "1"
  mount Website::Engine => "/website" if ENV.fetch("ENABLE_WEBSITE", "1") == "1"
  mount Report::Engine  => "/report"  if ENV.fetch("ENABLE_REPORT", "1") == "1"
end
