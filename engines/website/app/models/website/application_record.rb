module Analysis
  class ApplicationRecord < ::ActiveRecord::Base
    self.abstract_class = true

    # Every Analysis model uses the `analysis` database (PostgreSQL) declared in config/database.yml
    connects_to database: { writing: :analysis, reading: :analysis }
  end
end
