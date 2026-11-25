module Website
  # Login (401), permission (403) and JSON errors (404/400/422) come from System::BaseController.
  class ApplicationController < System::BaseController
    private

    # Only sites the current user may see. Anything else raises RecordNotFound -> 404,
    # so a user cannot even learn that another user's site exists.
    def find_accessible_site(id)
      Site.accessible_by(current_user).find(id)
    end
  end
end
