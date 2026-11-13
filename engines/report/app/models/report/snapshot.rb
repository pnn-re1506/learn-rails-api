module Report
  # A saved report: the user's analysis summary "frozen" at the moment it was created.
  # Later events in Analysis do not change an existing snapshot.
  class Snapshot < ApplicationRecord
    validates :user_id, presence: true
    validates :title, presence: true, length: { maximum: 200 }
  end
end
