require "test_helper"

# Tests the whole flow like a real client: signup -> login -> Website -> Report.
# Each request may touch a different database: System, Website and Report (3 databases, one MySQL server).
class ApiFlowTest < ActionDispatch::IntegrationTest
  # The JOIN endpoint reads a Website table through Report's connection. With transactional tests each
  # connection keeps its writes uncommitted, so that join would not see the sites the test just created.
  # So these tests really commit, and we empty the tables ourselves.
  self.use_transactional_tests = false

  setup    { clean_tables }
  teardown { clean_tables }

  # --- System ---

  test "signup returns a token that works on /me" do
    token = signup("bob@example.com")

    get "/system/me", headers: auth(token)

    assert_response :ok
    assert_equal "bob@example.com", response.parsed_body["email"]
  end

  test "signup rejects duplicated email and short password" do
    signup("bob@example.com")

    post "/system/signup", params: { user: { email: "BOB@example.com", password: "secret123" } }, as: :json
    assert_response :unprocessable_content

    post "/system/signup", params: { user: { email: "x@example.com", password: "123" } }, as: :json
    assert_response :unprocessable_content
  end

  test "login succeeds with right password and fails with wrong one" do
    signup("bob@example.com")

    post "/system/login", params: { user: { email: "bob@example.com", password: "secret123" } }, as: :json
    assert_response :ok
    assert response.parsed_body["token"].present?

    post "/system/login", params: { user: { email: "bob@example.com", password: "wrong" } }, as: :json
    assert_response :unauthorized
  end

  test "protected endpoints of every module reject missing or invalid token" do
    %w[/website/sites /report/details /report/reports/via_join /report/reports/via_service].each do |path|
      get path
      assert_response :unauthorized, "#{path} without token"

      get path, headers: auth("not-a-real-token")
      assert_response :unauthorized, "#{path} with a bad token"
    end
  end

  # --- Website ---

  test "create and list sites" do
    headers = auth(signup("bob@example.com"))

    shop = create_site(headers, "Shop.Example.com ", "Example Shop")
    assert_equal "shop.example.com", shop["domain"]   # normalized
    create_site(headers, "blog.example.com", "Example Blog")

    get "/website/sites", headers: headers
    assert_response :ok
    assert_equal %w[blog.example.com shop.example.com], response.parsed_body.map { |s| s["domain"] }

    get "/website/sites/#{shop['id']}", headers: headers
    assert_equal "Example Shop", response.parsed_body["name"]
  end

  test "site validation: required fields and unique domain" do
    headers = auth(signup("bob@example.com"))
    create_site(headers, "shop.example.com", "Shop")

    post "/website/sites", params: { site: { domain: "shop.example.com", name: "Again" } }, headers: headers, as: :json
    assert_response :unprocessable_content
    assert response.parsed_body["errors"]["domain"].present?

    post "/website/sites", params: { site: { domain: "", name: "" } }, headers: headers, as: :json
    assert_response :unprocessable_content
    assert response.parsed_body["errors"]["name"].present?
  end

  # --- Report: raw rows ---

  test "create a report row; the site must exist and the period must be valid" do
    headers = auth(signup("bob@example.com"))
    site = create_site(headers, "shop.example.com", "Shop")

    create_detail(headers, site["id"], "2026-10", 100)

    get "/report/details", headers: headers
    assert_equal [ "2026-10" ], response.parsed_body.map { |d| d["period"] }

    post "/report/details", params: { detail: { site_id: 999_999, period: "2026-10", visits: 1 } }, headers: headers, as: :json
    assert_response :unprocessable_content
    assert response.parsed_body["errors"]["site_id"].present?

    post "/report/details", params: { detail: { site_id: site["id"], period: "October", visits: 1 } }, headers: headers, as: :json
    assert_response :unprocessable_content
    assert response.parsed_body["errors"]["period"].present?
  end

  # --- Report: the final report, merged in two ways, must give the same answer ---

  test "final report via JOIN and via service return the same rows" do
    headers = auth(signup("bob@example.com"))
    shop = create_site(headers, "shop.example.com", "Example Shop")
    blog = create_site(headers, "blog.example.com", "Example Blog")
    create_detail(headers, shop["id"], "2026-10", 300, 900)
    create_detail(headers, blog["id"], "2026-10", 100, 150)

    [ "via_join", "via_service" ].each do |way|
      get "/report/reports/#{way}", headers: headers
      assert_response :ok
      report = response.parsed_body
      assert_equal way.delete_prefix("via_"), report["via"]
      assert_equal 2, report["count"]
      assert_equal 400, report["total_visits"]
      assert_equal 1050, report["total_page_views"]
      assert_equal [ "shop.example.com", "blog.example.com" ], report["rows"].map { |r| r.dig("site", "domain") }  # visits desc
      assert_equal "Example Shop", report["rows"].first.dig("site", "name")
    end
  end

  test "both ways support the same domain filter and sort" do
    headers = auth(signup("bob@example.com"))
    shop = create_site(headers, "shop.example.com", "Shop")
    blog = create_site(headers, "blog.example.com", "Blog")
    create_detail(headers, shop["id"], "2026-10", 300)
    create_detail(headers, blog["id"], "2026-10", 100)

    [ "via_join", "via_service" ].each do |way|
      get "/report/reports/#{way}", params: { domain: "blog" }, headers: headers
      assert_equal [ "blog.example.com" ], response.parsed_body["rows"].map { |r| r.dig("site", "domain") }, way

      get "/report/reports/#{way}", params: { sort: "domain" }, headers: headers
      assert_equal %w[blog.example.com shop.example.com], response.parsed_body["rows"].map { |r| r.dig("site", "domain") }, way
    end
  end

  test "a row whose site was deleted still appears, with site null, in both ways" do
    headers = auth(signup("bob@example.com"))
    site = create_site(headers, "shop.example.com", "Shop")
    create_detail(headers, site["id"], "2026-10", 300)
    Website::Site.find(site["id"]).destroy!   # nothing stops this: no foreign key across databases

    [ "via_join", "via_service" ].each do |way|
      get "/report/reports/#{way}", headers: headers
      assert_equal 1, response.parsed_body["count"], way
      assert_nil response.parsed_body["rows"].first["site"], way
    end
  end

  test "a user only sees their own report rows" do
    alice = auth(signup("alice@example.com"))
    bob   = auth(signup("bob@example.com"))
    site  = create_site(alice, "shop.example.com", "Shop")
    create_detail(alice, site["id"], "2026-10", 999)

    [ "via_join", "via_service" ].each do |way|
      get "/report/reports/#{way}", headers: bob
      assert_equal 0, response.parsed_body["count"], way
    end
  end

  private

  def clean_tables
    [ Report::Detail, Website::Site, System::User ].each(&:delete_all)
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
