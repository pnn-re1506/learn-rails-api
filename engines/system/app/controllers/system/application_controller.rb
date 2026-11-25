module System
  # Login (401), permission (403) and JSON errors (404/400/422) come from System::BaseController.
  class ApplicationController < BaseController
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
  end
end
