module System
  class ApplicationController < ActionController::API
    include Authentication   # who are you?        -> 401
    include Authorization    # are you allowed to? -> 403

    # Handle errors in one place so child controllers don't need their own rescue.
    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: "Not found" }, status: :not_found
    end

    rescue_from ActionController::ParameterMissing do |e|
      render json: { error: "Missing or invalid parameter: #{e.param}" }, status: :bad_request
    end

    private

    # Returns the token + user info. Only picks safe columns,
    # never expose password_digest.
    def render_auth(user, status:)
      render json: {
        token: JsonWebToken.encode(user.id),
        user: user_json(user)
      }, status: status
    end

    def user_json(user)
      user.as_json(only: %i[id email role])
    end

    def render_validation_errors(record)
      render json: { errors: record.errors }, status: :unprocessable_content
    end
  end
end
