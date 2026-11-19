module Website
  class ApplicationController < ActionController::API
    # Borrow login AND permission checks from the System module (through its "front doors").
    include System::Authentication   # -> current_user, 401
    include System::Authorization    # -> authorize!, 403

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

    # Only sites the current user may see. Anything else raises RecordNotFound -> 404,
    # so a user cannot even learn that another user's site exists.
    def find_accessible_site(id)
      Site.accessible_by(current_user).find(id)
    end
  end
end
