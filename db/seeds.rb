# Mock data for trying the API:  bin/rails db:seed   (safe to run more than once)
#
# Logins (password secret123 for all):
#   demo@example.com    member, OWNER of the 4 sites below
#   viewer@example.com  member, VIEWER of shop.example.com only (can see it, cannot edit it or add report rows)
#   admin@example.com   admin, sees and manages everything
# Data lives in 3 different databases, which is the whole point of the demo:
#   System::User   -> system_dev   (users)
#   Website::Site  -> website_dev  (domain, name)
#   Report::Detail -> report_dev   (monthly statistics, points to a site by id)

user   = System::User.find_or_create_by!(email: "demo@example.com")   { |u| u.password = "secret123" }
viewer = System::User.find_or_create_by!(email: "viewer@example.com") { |u| u.password = "secret123" }
System::User.find_or_create_by!(email: "admin@example.com") { |u| u.password = "secret123"; u.role = :admin }

sites = [
  [ "shop.example.com",   "Example Shop" ],
  [ "blog.example.com",   "Example Blog" ],
  [ "news.example.org",   "Daily News" ],
  [ "forum.example.net",  "Community Forum" ]
].map do |domain, name|
  Website::Site.find_or_create_by!(domain: domain) { |s| s.name = name }
end

# Permissions on each site (website database). demo owns everything, viewer may only look at the shop.
sites.each { |site| site.members.find_or_create_by!(user_id: user.id) { |m| m.role = :owner } }
sites.first.members.find_or_create_by!(user_id: viewer.id) { |m| m.role = :viewer }

# [site index, period, visits, page_views, bounce_rate]
stats = [
  [ 0, "2026-09", 12_000, 54_000, 41.50 ], [ 0, "2026-10", 15_500, 70_200, 38.20 ],
  [ 1, "2026-09",  4_300,  9_100, 62.00 ], [ 1, "2026-10",  5_100, 11_800, 58.75 ],
  [ 2, "2026-10", 30_250, 88_000, 47.10 ],
  [ 3, "2026-10",  1_900,  6_400, 35.00 ]
]

stats.each do |index, period, visits, page_views, bounce_rate|
  Report::Detail.find_or_create_by!(user_id: user.id, site_id: sites[index].id, period: period) do |d|
    d.visits = visits
    d.page_views = page_views
    d.bounce_rate = bounce_rate
  end
end

# (insert_all skips validations, so the "site must exist" check does not block it.)
# One row pointing to a site id that does not exist (id 999999): shows what happens
# when there is no foreign key between databases (site is null in the report).
Report::Detail.insert_all([ { user_id: user.id, site_id: 999_999, period: "2026-10", visits: 10, page_views: 20,
                              bounce_rate: 0, created_at: Time.current, updated_at: Time.current } ]) unless Report::Detail.exists?(user_id: user.id, site_id: 999_999)

puts "Seeded: #{System::User.count} users, #{Website::Site.count} sites, " \
     "#{Website::SiteMember.count} site members, #{Report::Detail.count} report rows"
