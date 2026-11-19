module Website
  # Basic information about one website, e.g. { domain: "example.com", name: "Example Shop" }
  class Site < ApplicationRecord
    # delete_all (no callbacks): when the whole site goes, its members go too, without
    # SiteMember's "keep the last owner" rule blocking it.
    has_many :members, class_name: "SiteMember", inverse_of: :site, dependent: :delete_all

    normalizes :domain, with: ->(domain) { domain.strip.downcase }

    validates :domain, presence: true, length: { maximum: 255 }, uniqueness: true
    validates :name, presence: true, length: { maximum: 200 }

    # The sites a user may see: all of them for an admin, otherwise only the ones they are a member of.
    # This is the "scope" half of authorization, used for lists and to find one record
    # (a site you cannot see is answered with 404, as if it did not exist).
    scope :accessible_by, ->(user) {
      user.admin? ? all : where(id: SiteMember.where(user_id: user.id).select(:site_id))
    }

    # "owner" / "editor" / "viewer", or nil if the user is not a member.
    def role_of(user)
      members.find_by(user_id: user.id)&.role
    end
  end
end
