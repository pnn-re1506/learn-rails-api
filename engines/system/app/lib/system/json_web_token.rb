# Wraps the `jwt` library so the rest of the app doesn't need to know its details.
#
# A JWT has 3 parts separated by dots:  header.payload.signature
#   - payload: the data we put in (here: user_id and the expiry time `exp`)
#   - signature: created with a secret. Anyone who edits the payload breaks the signature -> rejected.
# Note: the payload is only base64-encoded, NOT secret. Never put passwords in it.
module System
  module JsonWebToken
    ALGORITHM  = "HS256"
    EXPIRES_IN = 24.hours

    # Create a token for the given user_id
    def self.encode(user_id)
      payload = { user_id: user_id, exp: EXPIRES_IN.from_now.to_i }
      JWT.encode(payload, secret, ALGORITHM)
    end

    # Returns the payload (Hash) if the token is valid, otherwise nil.
    # jwt verifies the signature and `exp` itself; a bad or expired token raises JWT::DecodeError.
    def self.decode(token)
      payload, = JWT.decode(token, secret, true, algorithm: ALGORITHM)
      payload
    rescue JWT::DecodeError
      nil
    end

    # Uses Rails' secret_key_base as the signing key.
    # (development/test: Rails generates it and stores it in tmp/local_secret.txt)
    def self.secret
      Rails.application.secret_key_base
    end
  end
end
