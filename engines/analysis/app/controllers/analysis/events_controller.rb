module Analysis
  class EventsController < ApplicationController
    # GET /analysis/events              -> all of the user's events
    # GET /analysis/events?name=sale    -> filter by name
    def index
      events = user_events.order(created_at: :desc)
      events = events.where(name: params[:name]) if params[:name].present?

      render json: events
    end

    # POST /analysis/events   body: { "event": { "name": "sale", "value": 250 } }
    def create
      event = user_events.build(event_params)

      if event.save
        render json: event, status: :created
      else
        render_validation_errors(event)
      end
    end

    private

    # Always scope by the current user: a user only sees their own events.
    def user_events
      Event.where(user_id: current_user.id)
    end

    def event_params
      params.expect(event: %i[name value])
    end
  end
end
