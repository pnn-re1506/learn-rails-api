# The "front door" (public API) of the System module for other modules.
# A module that needs login just does: `include System::Authentication`
# and then uses `current_user` (a System::User). It doesn't need to know how JWT works.
module System
  module Authentication
    extend ActiveSupport::Concern

    included do
      # By default EVERY action requires login.
      # Public actions (signup, login) use `skip_before_action :authenticate_user!`.
      before_action :authenticate_user!
    end

    private

    attr_reader :current_user

    # The client sends the header:  Authorization: Bearer <token>
    def authenticate_user!
      token   = request.authorization.to_s[/\ABearer (.+)\z/, 1]
      payload = token && JsonWebToken.decode(token)
      @current_user = User.find_by(id: payload["user_id"]) if payload

      render json: { error: "Unauthorized" }, status: :unauthorized unless current_user
    end
  end
end
