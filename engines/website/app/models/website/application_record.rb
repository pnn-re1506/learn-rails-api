module Website
  class ApplicationRecord < ::ActiveRecord::Base
    self.abstract_class = true

    # Every Website model uses the `website` database (MySQL) declared in config/database.yml
    connects_to database: { writing: :website, reading: :website }
  end
end
