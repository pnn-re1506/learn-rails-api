require "test_helper"

# Query params of the list endpoints (filter / search / sort), provided by System::CrudActions.
class ListFilterTest < ActionDispatch::IntegrationTest
  include ApiTestHelpers

  self.use_transactional_tests = false

  setup    { clean_tables }
  teardown { clean_tables }

  test "sites: ?q searches domain and name, ?sort and ?direction order the result" do
    headers = auth(signup("bob@example.com"))
    create_site(headers, "alpha.com", "Blog")
    create_site(headers, "beta.com", "Big Shop")
    create_site(headers, "shopzone.com", "Zone")

    get "/website/sites", params: { q: "shop" }, headers: headers
    assert_equal %w[beta.com shopzone.com], response.parsed_body.map { |s| s["domain"] }   # default order: domain

    get "/website/sites", params: { sort: "domain", direction: "desc" }, headers: headers
    assert_equal %w[shopzone.com beta.com alpha.com], response.parsed_body.map { |s| s["domain"] }
  end

  test "sites: unknown sort field is ignored" do
    headers = auth(signup("bob@example.com"))
    create_site(headers, "b.com", "B")
    create_site(headers, "a.com", "A")

    get "/website/sites", params: { sort: "password_digest; drop table" }, headers: headers

    assert_response :ok
    assert_equal %w[a.com b.com], response.parsed_body.map { |s| s["domain"] }
  end

  test "details: filter by site_id and period, sort by visits" do
    headers = auth(signup("bob@example.com"))
    site1 = create_site(headers, "a.com", "A")["id"]
    site2 = create_site(headers, "b.com", "B")["id"]
    create_detail(headers, site1, "2026-09", 100)
    create_detail(headers, site1, "2026-10", 300)
    create_detail(headers, site2, "2026-10", 200)

    get "/report/details", params: { site_id: site1 }, headers: headers
    assert_equal [ 100, 300 ], response.parsed_body.map { |d| d["visits"] }

    get "/report/details", params: { period: "2026-10" }, headers: headers
    assert_equal [ 300, 200 ], response.parsed_body.map { |d| d["visits"] }

    get "/report/details", params: { sort: "visits", direction: "desc" }, headers: headers
    assert_equal [ 300, 200, 100 ], response.parsed_body.map { |d| d["visits"] }
  end

  test "filters never show rows of another user" do
    alice = auth(signup("alice@example.com"))
    bob   = auth(signup("bob@example.com"))
    site  = create_site(alice, "a.com", "A")["id"]
    create_detail(alice, site, "2026-10", 100)

    get "/report/details", params: { period: "2026-10" }, headers: bob

    assert_response :ok
    assert_empty response.parsed_body
  end
end
