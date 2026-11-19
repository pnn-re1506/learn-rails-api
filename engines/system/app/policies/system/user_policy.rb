module System
  # Who may manage user accounts. Pure RBAC: only the global role matters.
  class UserPolicy < Policy
    # GET /system/users
    def index?
      admin?
    end

    # PATCH /system/users/:id  (change a role)
    # An admin cannot change their OWN role, so the last admin cannot lock everybody out by mistake.
    def update?
      admin? && record != user
    end
  end
end
