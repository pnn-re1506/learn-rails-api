module Analysis
  class SummariesController < ApplicationController
    # GET /analysis/summary  -> [{ "name": "sale", "count": 2, "total": 400, "average": 200.0 }, ...]
    def show
      render json: SummaryService.for_user(current_user.id)
    end
  end
end
