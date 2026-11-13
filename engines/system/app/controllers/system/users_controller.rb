module System
  class UsersController < ApplicationController
    skip_before_action :authenticate_user!, only: :create

    # POST /system/signup   body: { "user": { "email": "...", "password": "..." } }
    def create
      user = User.new(user_params)

      if user.save
        render_auth(user, status: :created)
      else
        render_validation_errors(user)
      end
    end

    # GET /system/me   (token required) -> current_user is set in authenticate_user!
    def me
      render json: current_user.as_json(only: %i[id email])
    end

    private

    # Strong parameters: only these fields are allowed into the model.
    # `expect` (Rails 8) both requires the `user` key and filters the permitted fields.
    def user_params
      params.expect(user: %i[email password])
    end
  end
end
