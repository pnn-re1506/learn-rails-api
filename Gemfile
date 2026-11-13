source "https://rubygems.org"

gem "rails", "~> 8.1.4"
gem "puma", ">= 5.0"        # Web server
gem "mysql2", "~> 0.5"      # Driver for the System module's database (MySQL)
gem "pg", "~> 1.5"          # Driver for the Analysis and Report modules' databases (PostgreSQL)

# --- Modules (Rails Engines) live in the engines/ directory ---
# Gems used by only one module are declared in that module's .gemspec (e.g. bcrypt and jwt in system.gemspec).
gem "system",   path: "engines/system"
gem "analysis", path: "engines/analysis"
gem "report",   path: "engines/report"

gem "tzinfo-data", platforms: %i[windows jruby]
