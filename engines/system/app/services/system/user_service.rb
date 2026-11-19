# "Front door" of the System module for other modules that need user data (e.g. Website's site members).
# They ask by email / ids and get plain values back; they never query System::User themselves.
module System
  class UserService
    # Id of the account with this email, or nil. The email is normalized like on signup.
    def self.id_by_email(email)
      User.find_by(email: email.to_s)&.id
    end

    # { user_id => email } for the given ids (one query).
    def self.emails_for(ids)
      User.where(id: ids).pluck(:id, :email).to_h
    end
  end
end
