module Website
  class ApplicationController < ActionController::API
    # Borrow login from the System module (through its "front door", System::Authentication).
    include System::Authentication

    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: "Not found" }, status: :not_found
    end

    rescue_from ActionController::ParameterMissing do |e|
      render json: { error: "Missing or invalid parameter: #{e.param}" }, status: :bad_request
    end

    private

    def render_validation_errors(record)
      render json: { errors: record.errors }, status: :unprocessable_content
    end
  end
end
