module System
  class ApplicationRecord < ::ActiveRecord::Base
    self.abstract_class = true

    # Every System model uses the `system` database (MySQL) declared in config/database.yml
    connects_to database: { writing: :system, reading: :system }
  end
end
