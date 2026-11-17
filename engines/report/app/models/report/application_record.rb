module Report
  class ApplicationRecord < ::ActiveRecord::Base
    self.abstract_class = true

    # Every Report model uses the `report` database (MySQL) declared in config/database.yml
    connects_to database: { writing: :report, reading: :report }
  end
end
