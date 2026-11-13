require "test_helper"

# Tests the whole flow like a real client: signup -> login -> Analysis -> Report.
# Each request may touch a different database: System (MySQL), Analysis and Report (PostgreSQL).
class ApiFlowTest < ActionDispatch::IntegrationTest
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
    %w[/analysis/events /analysis/summary /report/snapshots].each do |path|
      get path
      assert_response :unauthorized, "#{path} without token"

      get path, headers: auth("not-a-real-token")
      assert_response :unauthorized, "#{path} with a bad token"
    end
  end

  # --- Analysis ---

  test "create events and get the summary" do
    headers = auth(signup("bob@example.com"))

    create_event(headers, "sale", 100)
    create_event(headers, "sale", 300)
    create_event(headers, "page_view", 1)

    get "/analysis/events", params: { name: "sale" }, headers: headers
    assert_response :ok
    assert_equal [ 300, 100 ], response.parsed_body.map { |e| e["value"] }

    get "/analysis/summary", headers: headers
    assert_response :ok
    assert_equal [
      { "name" => "page_view", "count" => 1, "total" => 1, "average" => 1.0 },
      { "name" => "sale", "count" => 2, "total" => 400, "average" => 200.0 }
    ], response.parsed_body
  end

  test "create event with invalid data returns validation errors" do
    headers = auth(signup("bob@example.com"))

    post "/analysis/events", params: { event: { name: "", value: "abc" } }, headers: headers, as: :json

    assert_response :unprocessable_content
    assert response.parsed_body["errors"]["name"].present?
    assert response.parsed_body["errors"]["value"].present?
  end

  test "a user only sees their own events in the summary" do
    alice = auth(signup("alice@example.com"))
    bob   = auth(signup("bob@example.com"))
    create_event(alice, "sale", 999)

    get "/analysis/summary", headers: bob

    assert_empty response.parsed_body
  end

  # --- Report (reads Analysis through Analysis::SummaryService) ---

  test "snapshot stores a copy of the analysis summary" do
    headers = auth(signup("bob@example.com"))
    create_event(headers, "sale", 250)

    post "/report/snapshots", params: { snapshot: { title: "November" } }, headers: headers, as: :json
    assert_response :created
    id = response.parsed_body["id"]
    assert_equal [ { "name" => "sale", "count" => 1, "total" => 250, "average" => 250.0 } ],
                 response.parsed_body["data"]

    # A new event does not change the old snapshot
    create_event(headers, "sale", 50)
    get "/report/snapshots/#{id}", headers: headers
    assert_equal 250, response.parsed_body["data"].first["total"]

    get "/report/snapshots", headers: headers
    assert_equal [ id ], response.parsed_body.map { |s| s["id"] }

    delete "/report/snapshots/#{id}", headers: headers
    assert_response :no_content

    get "/report/snapshots/#{id}", headers: headers
    assert_response :not_found
  end

  test "create snapshot without title returns validation errors" do
    headers = auth(signup("bob@example.com"))

    post "/report/snapshots", params: { snapshot: { title: "" } }, headers: headers, as: :json

    assert_response :unprocessable_content
    assert response.parsed_body["errors"]["title"].present?
  end

  test "a user cannot access another user's snapshot" do
    alice = auth(signup("alice@example.com"))
    bob   = auth(signup("bob@example.com"))

    post "/report/snapshots", params: { snapshot: { title: "Alice secret" } }, headers: alice, as: :json
    id = response.parsed_body["id"]

    get "/report/snapshots/#{id}", headers: bob
    assert_response :not_found

    delete "/report/snapshots/#{id}", headers: bob
    assert_response :not_found
  end

  private

  # Sign up and return the token
  def signup(email)
    post "/system/signup", params: { user: { email: email, password: "secret123" } }, as: :json
    assert_response :created
    response.parsed_body["token"]
  end

  def create_event(headers, name, value)
    post "/analysis/events", params: { event: { name: name, value: value } }, headers: headers, as: :json
    assert_response :created
  end

  def auth(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
