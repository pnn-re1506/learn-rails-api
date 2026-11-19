module Website
  class SitesController < ApplicationController
    # GET /website/sites   -> only the sites the user is a member of (all of them for an admin)
    def index
      render json: Site.accessible_by(current_user).order(:domain)
    end

    # GET /website/sites/:id
    def show
      render json: find_accessible_site(params[:id])
    end

    # POST /website/sites   body: { "site": { "domain": "example.com", "name": "Example Shop" } }
    # Any logged-in user may create a site and becomes its owner.
    def create
      site = Site.new(site_params)
      site.members.build(user_id: current_user.id, role: :owner)

      if site.save   # site + owner membership are saved in one transaction
        render json: site, status: :created
      else
        render_validation_errors(site)
      end
    end

    # PATCH /website/sites/:id   (owner, editor or admin)
    def update
      site = find_accessible_site(params[:id])
      authorize!(SitePolicy.new(current_user, site), :update?)

      if site.update(site_params)
        render json: site
      else
        render_validation_errors(site)
      end
    end

    # DELETE /website/sites/:id   (owner or admin)
    def destroy
      site = find_accessible_site(params[:id])
      authorize!(SitePolicy.new(current_user, site), :destroy?)

      site.destroy!
      head :no_content
    end

    private

    def site_params
      params.expect(site: %i[domain name])
    end
  end
end
