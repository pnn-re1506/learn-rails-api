module Website
  # Basic information about one website, e.g. { domain: "example.com", name: "Example Shop" }
  class Site < ApplicationRecord
    normalizes :domain, with: ->(domain) { domain.strip.downcase }

    validates :domain, presence: true, length: { maximum: 255 }, uniqueness: true
    validates :name, presence: true, length: { maximum: 200 }
  end
end
