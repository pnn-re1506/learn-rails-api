module Website
  class SitesController < ApplicationController
    # GET /website/sites
    def index
      render json: Site.order(:domain)
    end

    # GET /website/sites/:id
    def show
      render json: Site.find(params[:id])
    end

    # POST /website/sites   body: { "site": { "domain": "example.com", "name": "Example Shop" } }
    def create
      site = Site.new(site_params)

      if site.save
        render json: site, status: :created
      else
        render_validation_errors(site)
      end
    end

    private

    def site_params
      params.expect(site: %i[domain name])
    end
  end
end
