module System
  class User < ApplicationRecord
    # Adds `password=`, `authenticate(...)` and hashes the password with bcrypt
    # into the `password_digest` column. The plain password is never stored.
    has_secure_password

    # GLOBAL role (RBAC). Adds `member?`, `admin?`, `admin!`, scopes `User.admin`...
    # `validate: true`: an unknown value ("boss") becomes a validation error (422) instead of an exception.
    # Roles that only make sense for one resource (owner/editor/viewer of a site) do NOT live here:
    # they belong to the module that owns that resource (Website::SiteMember).
    enum :role, { member: 0, admin: 1 }, default: :member, validate: true

    # Note: do NOT declare `has_many :details` here. Details belong to the Report module
    # (and live in another database). System must not know about other modules
    # (one-way dependency: Website -> System, Report -> System).

    # Normalize the email before saving / searching: "  Bob@Mail.COM " -> "bob@mail.com"
    normalizes :email, with: ->(email) { email.strip.downcase }

    validates :email, presence: true,
                      format: { with: URI::MailTo::EMAIL_REGEXP },
                      uniqueness: true
    validates :password, length: { minimum: 6 }, allow_nil: true
  end
end
