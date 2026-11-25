module Report
  # Raw statistics rows. Only Report's own data: there is no website name/domain here.
  # Routes expose only index and create; CRUD comes from System::CrudActions.
  class DetailsController < ApplicationController
    private

    def model_class = Detail

    # Always scope by the current user: a user only sees their own rows.
    def scope = Detail.where(user_id: current_user.id)

    def collection = scope.order(:period, :id)

    # GET /report/details?site_id=1&period=2026-10&sort=visits&direction=desc
    def filter_fields   = %i[site_id period]
    def sortable_fields = %i[id site_id period visits page_views bounce_rate]

    # body: { "detail": { "site_id": 1, "period": "2026-10", "visits": 1200, "page_views": 5400, "bounce_rate": 41.5 } }
    def record_params = params.expect(detail: %i[site_id period visits page_views bounce_rate])

    # 403 if the site exists but you are not its owner/editor (422 for invalid data is checked first).
    def authorize_record!(action, detail)
      authorize!(DetailPolicy.new(current_user, detail), :"#{action}?")
    end
  end
end
