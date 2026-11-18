# Bundler.require only loads gems listed in the main Gemfile, not the dependencies
# declared in system.gemspec, so the engine requires them itself.
require "bcrypt"
require "jwt"
module System
  # No `system_` table prefix: every module has its own database, so names cannot clash.
  # Defined BEFORE the engine is loaded, because `isolate_namespace` only adds its prefix when missing.
  def self.table_name_prefix = ""
end

require "system/engine"
