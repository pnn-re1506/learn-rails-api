module Analysis
  # One measured event of a user, e.g. { name: "page_view", value: 1 } or { name: "sale", value: 250 }
  class Event < ApplicationRecord
    validates :user_id, presence: true
    validates :name, presence: true, length: { maximum: 100 }
    validates :value, numericality: { only_integer: true }
  end
end
