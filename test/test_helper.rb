ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Helpers shared by the integration tests: they call the API like a real client.
module ApiTestHelpers
  private

  # Children before parents: site_members has a foreign key to sites.
  def clean_tables
    [ Report::Detail, Website::SiteMember, Website::Site, System::User ].each(&:delete_all)
  end

  # Sign up and return the token
  def signup(email)
    post "/system/signup", params: { user: { email: email, password: "secret123" } }, as: :json
    assert_response :created
    response.parsed_body["token"]
  end

  def create_site(headers, domain, name)
    post "/website/sites", params: { site: { domain: domain, name: name } }, headers: headers, as: :json
    assert_response :created
    response.parsed_body
  end

  def create_detail(headers, site_id, period, visits, page_views = 0)
    post "/report/details",
         params: { detail: { site_id: site_id, period: period, visits: visits, page_views: page_views, bounce_rate: 40 } },
         headers: headers, as: :json
    assert_response :created
  end

  def auth(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
