module Report
  # Who may write a statistics row. Reading needs no policy: DetailsController/ReportsController
  # already scope every query to `user_id: current_user.id` (you only ever see your own rows).
  class DetailPolicy < System::Policy
    # The site belongs to the Website module, so ask Website (through its front door) instead of
    # reading its members table: "is this user an owner/editor of the site, or an admin?"
    def create?
      Website::SiteService.can_write_reports?(user, record.site_id)
    end
  end
end
