module Website
  # Links a user (System::User, other database) to a site with a role ON THAT SITE:
  #   viewer -> may see the site
  #   editor -> + edit the site, add report rows for it
  #   owner  -> + delete the site, manage its members
  # What each role may do is written in Website::SitePolicy, not here.
  class SiteMember < ApplicationRecord
    belongs_to :site

    enum :role, { viewer: 0, editor: 1, owner: 2 }, validate: true

    validates :user_id, presence: true, uniqueness: { scope: :site_id }

    # A site must always keep at least one owner, otherwise nobody (except an admin) could manage it.
    validate :keep_one_owner, on: :update
    before_destroy :prevent_removing_last_owner

    private

    def keep_one_owner
      return unless role_changed? && role_was == "owner" && last_owner?

      errors.add(:role, "cannot change: the site must keep at least one owner")
    end

    def prevent_removing_last_owner
      return unless owner? && last_owner?

      errors.add(:base, "Cannot remove the last owner of the site")
      throw :abort
    end

    def last_owner?
      site.members.owner.where.not(id: id).none?
    end
  end
end
