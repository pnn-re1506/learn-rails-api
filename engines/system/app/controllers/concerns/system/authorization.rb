# The second "front door" of the System module: AUTHORIZATION ("what are you allowed to do?").
#
#   Authentication (System::Authentication) -> WHO are you?          fails with 401 Unauthorized
#   Authorization  (System::Authorization)  -> are you ALLOWED to?   fails with 403 Forbidden
#
# A module includes both, then asks a policy before doing something:
#   authorize!(Website::SitePolicy.new(current_user, site), :update?)
# The policy only answers true/false. This concern turns `false` into an exception, and the
# exception into a 403 response, so a controller never has to write the "forbidden" branch itself.
module System
  module Authorization
    extend ActiveSupport::Concern

    class NotAuthorized < StandardError; end

    included do
      rescue_from NotAuthorized do
        render json: { error: "Forbidden" }, status: :forbidden
      end
    end

    private

    # Raises NotAuthorized unless `policy.<action>` is true. Returns the policy's record for convenience.
    def authorize!(policy, action)
      raise NotAuthorized, "#{policy.class}##{action}" unless policy.public_send(action)

      policy.record
    end
  end
end
