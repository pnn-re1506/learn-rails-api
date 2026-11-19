module Website
  # What a user may do on ONE site. Combines both kinds of authorization:
  #   - global role (RBAC):     an admin may do everything     -> `admin?`
  #   - role on this resource:  owner / editor / viewer         -> `role`
  class SitePolicy < System::Policy
    def show?
      admin? || role.present?
    end

    def update?
      admin? || role.in?(%w[owner editor])
    end

    def destroy?
      admin? || role == "owner"
    end

    def manage_members?
      admin? || role == "owner"
    end

    # Used by the Report module (through Website::SiteService): who may add statistics for this site.
    def write_reports?
      update?
    end

    private

    # Asked at most once per policy object (one query).
    def role
      return @role if defined?(@role)

      @role = record.role_of(user)
    end
  end
end
