Rails.application.configure do
  config.enable_reloading = true            # Code changes take effect immediately, no restart needed
  config.eager_load = false
  config.consider_all_requests_local = true # Show detailed errors when debugging
  config.cache_store = :memory_store
  config.active_support.deprecation = :log
end
