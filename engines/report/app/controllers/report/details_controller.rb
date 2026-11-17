module Report
  # Raw statistics rows. Only Report's own data: there is no website name/domain here.
  class DetailsController < ApplicationController
    # GET /report/details
    def index
      render json: user_details.order(:period, :id)
    end

    # POST /report/details
    #   body: { "detail": { "site_id": 1, "period": "2026-10", "visits": 1200, "page_views": 5400, "bounce_rate": 41.5 } }
    def create
      detail = user_details.build(detail_params)

      if detail.save
        render json: detail, status: :created
      else
        render_validation_errors(detail)
      end
    end

    private

    # Always scope by the current user: a user only sees their own rows.
    def user_details
      Detail.where(user_id: current_user.id)
    end

    def detail_params
      params.expect(detail: %i[site_id period visits page_views bounce_rate])
    end
  end
end
