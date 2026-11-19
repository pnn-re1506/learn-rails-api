# Signup always creates a `member` (the role is not a permitted param), so the FIRST admin
# has to be made from the server side:
#   bin/rails system:make_admin EMAIL=you@example.com
namespace :system do
  desc "Give the admin role to an existing user (EMAIL=...)"
  task make_admin: :environment do
    user = System::User.find_by!(email: ENV.fetch("EMAIL"))
    user.admin!
    puts "#{user.email} is now admin"
  end
end
