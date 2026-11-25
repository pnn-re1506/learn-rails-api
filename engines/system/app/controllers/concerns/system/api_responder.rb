# Shared JSON error handling for every API controller (System, Website, Report).
# Included by System::BaseController, so engines no longer repeat these rescue_from blocks.
module System
  module ApiResponder
    extend ActiveSupport::Concern

    included do
      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "Not found" }, status: :not_found
      end

      rescue_from ActionController::ParameterMissing do |e|
        render json: { error: "Missing or invalid parameter: #{e.param}" }, status: :bad_request
      end
    end

    private

    def render_validation_errors(record)
      render json: { errors: record.errors }, status: :unprocessable_content
    end
  end
end
