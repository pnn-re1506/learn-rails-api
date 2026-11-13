module System
  class SessionsController < ApplicationController
    skip_before_action :authenticate_user!

    # POST /system/login   body: { "user": { "email": "...", "password": "..." } }
    def create
      credentials = params.expect(user: %i[email password])

      user = User.find_by(email: credentials[:email])

      # `authenticate` compares the submitted password with password_digest;
      # returns the user if correct, false otherwise.
      if user&.authenticate(credentials[:password])
        render_auth(user, status: :ok)
      else
        # Deliberately use one shared message for "wrong email" and "wrong password"
        # so attackers can't probe which emails are registered.
        render json: { error: "Invalid email or password" }, status: :unauthorized
      end
    end
  end
end
