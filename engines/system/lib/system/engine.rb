module System
  class Engine < ::Rails::Engine
    # Isolate the namespace: the engine's controllers/models/routes live under `System::`,
    # and table names automatically get the `system_` prefix (e.g. system_users).
    # Migrations are NOT appended to the main app: `migrations_paths` in config/database.yml
    # sends engines/system/db/migrate to the `system` database.
    isolate_namespace System
  end
end
