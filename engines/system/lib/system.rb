# Bundler.require only loads gems listed in the main Gemfile, not the dependencies
# declared in system.gemspec, so the engine requires them itself.
require "bcrypt"
require "jwt"
require "system/engine"

module System
end
