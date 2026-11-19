# Base class of every policy, in every module.
#
# A policy answers "may `user` do <action> on `record`?" with plain Ruby methods ending in `?`.
# It never renders, never raises: controllers call it through `authorize!` (System::Authorization).
# Everything is forbidden unless a subclass says otherwise (deny by default).
module System
  class Policy
    attr_reader :user, :record

    def initialize(user, record)
      @user   = user
      @record = record
    end

    private

    # Global admins pass every check that uses this helper.
    def admin?
      user.admin?
    end
  end
end
