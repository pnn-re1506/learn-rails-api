module System
  class UsersController < ApplicationController
    skip_before_action :authenticate_user!, only: :create

    # POST /system/signup   body: { "user": { "email": "...", "password": "..." } }
    # Always creates a `member`: `role` is not in user_params, so a client sending
    # { "role": "admin" } is simply ignored (protection against mass assignment).
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
      render json: user_json(current_user)
    end

    # GET /system/users   (admin only)
    def index
      authorize!(UserPolicy.new(current_user, User), :index?)

      render json: User.order(:id).map { |user| user_json(user) }
    end

    # PATCH /system/users/:id   body: { "user": { "role": "admin" } }   (admin only, not on yourself)
    def update
      user = User.find(params[:id])
      authorize!(UserPolicy.new(current_user, user), :update?)

      if user.update(params.expect(user: [ :role ]))
        render json: user_json(user)
      else
        render_validation_errors(user)
      end
    end

    private

    # Strong parameters: only these fields are allowed into the model.
    # `expect` (Rails 8) both requires the `user` key and filters the permitted fields.
    def user_params
      params.expect(user: %i[email password])
    end
  end
end
