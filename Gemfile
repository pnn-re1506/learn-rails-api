source "https://rubygems.org"

gem "rails", "~> 8.1.4"
gem "puma", ">= 5.0"        # Web server
gem "mysql2", "~> 0.5"      # Driver for all modules' databases (3 MySQL databases on one server)

# --- Modules (Rails Engines) live in the engines/ directory ---
# Gems used by only one module are declared in that module's .gemspec (e.g. bcrypt and jwt in system.gemspec).
gem "system",   path: "engines/system"
gem "website",  path: "engines/website"
gem "report",   path: "engines/report"

gem "tzinfo-data", platforms: %i[windows jruby]
