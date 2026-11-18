require_relative "boot"

require "rails"
# Only load the parts of Rails this API needs
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module LearnApi
  class Application < Rails::Application
    config.load_defaults 8.1

    # API mode: drops web-only middleware (session, cookie, flash...)
    # and controllers inherit from ActionController::API instead of ActionController::Base
    config.api_only = true

    # No db/*_schema.rb: the report database has a FEDERATED table whose CONNECTION names a MySQL SERVER
    # per environment (website_development, website_test). A schema file dumped from development
    # would make the test database read development data, so databases are always built from migrations.
    config.active_record.dump_schema_after_migration = false
  end
end
