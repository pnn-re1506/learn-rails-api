module Website
  # CRUD comes from System::CrudActions. Only the site-specific rules are written here.
  class SitesController < ApplicationController
    private

    def model_class = Site

    # Only the sites the user is a member of (all of them for an admin); others are 404.
    def scope = Site.accessible_by(current_user)

    def collection = scope.order(:domain)

    # GET /website/sites?q=shop&sort=domain&direction=desc
    def search_fields = %i[domain name]

    # body: { "site": { "domain": "example.com", "name": "Example Shop" } }
    def record_params = params.expect(site: %i[domain name])

    # Any logged-in user may create a site and becomes its owner
    # (site + owner membership are saved in one transaction).
    def build_record
      Site.new(record_params).tap { |site| site.members.build(user_id: current_user.id, role: :owner) }
    end

    # update: owner, editor or admin. destroy: owner or admin. create: anyone logged in.
    def authorize_record!(action, site)
      return if action == :create

      authorize!(SitePolicy.new(current_user, site), :"#{action}?")
    end
  end
end
