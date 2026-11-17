module System
  class User < ApplicationRecord
    # Adds `password=`, `authenticate(...)` and hashes the password with bcrypt
    # into the `password_digest` column. The plain password is never stored.
    has_secure_password

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
