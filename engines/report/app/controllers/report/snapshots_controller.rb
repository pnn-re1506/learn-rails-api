module Report
  class SnapshotsController < ApplicationController
    before_action :set_snapshot, only: %i[show destroy]

    # GET /report/snapshots
    def index
      render json: user_snapshots.order(created_at: :desc)
    end

    # GET /report/snapshots/:id
    def show
      render json: @snapshot
    end

    # POST /report/snapshots   body: { "snapshot": { "title": "November report" } }
    # Reads the summary from the Analysis module (PostgreSQL `analysis` DB) through its service,
    # then stores a copy in the Report module's own database. No cross-database JOIN.
    def create
      snapshot = user_snapshots.build(snapshot_params)
      snapshot.data = Analysis::SummaryService.for_user(current_user.id)

      if snapshot.save
        render json: snapshot, status: :created
      else
        render_validation_errors(snapshot)
      end
    end

    # DELETE /report/snapshots/:id
    def destroy
      @snapshot.destroy
      head :no_content
    end

    private

    # Always scope by the current user: other people's snapshots return 404.
    def user_snapshots
      Snapshot.where(user_id: current_user.id)
    end

    def set_snapshot
      @snapshot = user_snapshots.find(params[:id])
    end

    def snapshot_params
      params.expect(snapshot: %i[title])
    end
  end
end
