module System
  # Base class of every API controller in every engine.
  #   - Authentication (401) and Authorization (403) from System's "front doors"
  #   - ApiResponder: 404 / 400 / 422 JSON errors
  #   - CrudActions: index/show/create/update/destroy, customizable through hooks
  class BaseController < ActionController::API
    include Authentication
    include Authorization
    include ApiResponder
    include CrudActions
  end
end
