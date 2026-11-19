require "test_helper"

# Authorization = "what may a logged-in user do?"
#   401: no / bad token (authentication)     403: logged in, but not allowed (authorization)
#   404: the resource is hidden from you (another user's site), as if it did not exist
class AuthorizationTest < ActionDispatch::IntegrationTest
  include ApiTestHelpers

  self.use_transactional_tests = false   # same reason as ApiFlowTest

  setup    { clean_tables }
  teardown { clean_tables }

  # --- Global role (System) ---

  test "signup always creates a member, even if the client sends a role" do
    post "/system/signup", params: { user: { email: "eve@example.com", password: "secret123", role: "admin" } }, as: :json

    assert_response :created
    assert_equal "member", response.parsed_body.dig("user", "role")
    assert System::User.find_by(email: "eve@example.com").member?
  end

  test "only an admin may list users and change roles" do
    bob   = auth(signup("bob@example.com"))
    admin = auth(signup("admin@example.com"))
    make_admin("admin@example.com")
    bob_id = System::User.find_by(email: "bob@example.com").id

    get "/system/users", headers: bob
    assert_response :forbidden
    patch "/system/users/#{bob_id}", params: { user: { role: "admin" } }, headers: bob, as: :json
    assert_response :forbidden

    get "/system/users", headers: admin
    assert_response :ok
    assert_equal %w[bob@example.com admin@example.com], response.parsed_body.map { |u| u["email"] }

    patch "/system/users/#{bob_id}", params: { user: { role: "admin" } }, headers: admin, as: :json
    assert_response :ok
    assert_equal "admin", response.parsed_body["role"]

    patch "/system/users/#{bob_id}", params: { user: { role: "boss" } }, headers: admin, as: :json
    assert_response :unprocessable_content
  end

  test "an admin cannot change their own role" do
    admin = auth(signup("admin@example.com"))
    make_admin("admin@example.com")

    patch "/system/users/#{System::User.find_by(email: 'admin@example.com').id}",
          params: { user: { role: "member" } }, headers: admin, as: :json
    assert_response :forbidden
  end

  test "a role change takes effect immediately, without a new token" do
    token = signup("bob@example.com")

    get "/system/users", headers: auth(token)
    assert_response :forbidden

    make_admin("bob@example.com")
    get "/system/users", headers: auth(token)   # same token: the role is read from the database
    assert_response :ok
  end

  # --- Site visibility (Website, scope) ---

  test "a user only sees the sites they are a member of; other sites are 404" do
    alice = auth(signup("alice@example.com"))
    bob   = auth(signup("bob@example.com"))
    shop  = create_site(alice, "shop.example.com", "Shop")
    create_site(bob, "blog.example.com", "Blog")

    get "/website/sites", headers: bob
    assert_equal [ "blog.example.com" ], response.parsed_body.map { |s| s["domain"] }

    get "/website/sites/#{shop['id']}", headers: bob
    assert_response :not_found
    patch "/website/sites/#{shop['id']}", params: { site: { name: "Hacked" } }, headers: bob, as: :json
    assert_response :not_found
    get "/website/sites/#{shop['id']}/members", headers: bob
    assert_response :not_found
  end

  test "an admin sees and manages every site" do
    alice = auth(signup("alice@example.com"))
    admin = auth(signup("admin@example.com"))
    make_admin("admin@example.com")
    shop = create_site(alice, "shop.example.com", "Shop")

    get "/website/sites", headers: admin
    assert_equal [ "shop.example.com" ], response.parsed_body.map { |s| s["domain"] }

    patch "/website/sites/#{shop['id']}", params: { site: { name: "Renamed" } }, headers: admin, as: :json
    assert_response :ok

    delete "/website/sites/#{shop['id']}", headers: admin
    assert_response :no_content
  end

  # --- Roles on one site (Website, policy) ---

  test "the creator becomes owner; viewer may look, editor may edit, only owner may delete or manage members" do
    owner  = auth(signup("owner@example.com"))
    editor = auth(signup("editor@example.com"))
    viewer = auth(signup("viewer@example.com"))
    site   = create_site(owner, "shop.example.com", "Shop")
    path   = "/website/sites/#{site['id']}"

    add_member(owner, site, "editor@example.com", "editor")
    add_member(owner, site, "viewer@example.com", "viewer")

    get "#{path}/members", headers: viewer
    assert_response :ok
    assert_equal({ "owner@example.com" => "owner", "editor@example.com" => "editor", "viewer@example.com" => "viewer" },
                 response.parsed_body.to_h { |m| [ m["email"], m["role"] ] })

    # viewer: read only
    get path, headers: viewer
    assert_response :ok
    patch path, params: { site: { name: "By viewer" } }, headers: viewer, as: :json
    assert_response :forbidden

    # editor: may edit, may not delete or manage members
    patch path, params: { site: { name: "By editor" } }, headers: editor, as: :json
    assert_response :ok
    assert_equal "By editor", response.parsed_body["name"]
    delete path, headers: editor
    assert_response :forbidden
    post "#{path}/members", params: { member: { email: "x@example.com", role: "owner" } }, headers: editor, as: :json
    assert_response :forbidden

    # owner: may do everything
    delete path, headers: owner
    assert_response :no_content
    assert_equal 0, Website::SiteMember.count   # memberships are removed with the site
  end

  test "adding members: unknown email, invalid role and duplicates are rejected" do
    owner = auth(signup("owner@example.com"))
    signup("bob@example.com")
    site = create_site(owner, "shop.example.com", "Shop")
    path = "/website/sites/#{site['id']}/members"

    post path, params: { member: { email: "nobody@example.com", role: "viewer" } }, headers: owner, as: :json
    assert_response :unprocessable_content

    post path, params: { member: { email: "bob@example.com", role: "superuser" } }, headers: owner, as: :json
    assert_response :unprocessable_content

    add_member(owner, site, "bob@example.com", "viewer")
    post path, params: { member: { email: "bob@example.com", role: "editor" } }, headers: owner, as: :json
    assert_response :unprocessable_content
  end

  test "a site always keeps at least one owner" do
    owner    = auth(signup("owner@example.com"))
    owner_id = System::User.find_by(email: "owner@example.com").id
    site     = create_site(owner, "shop.example.com", "Shop")
    path     = "/website/sites/#{site['id']}/members"

    patch "#{path}/#{owner_id}", params: { member: { role: "viewer" } }, headers: owner, as: :json
    assert_response :unprocessable_content
    delete "#{path}/#{owner_id}", headers: owner
    assert_response :unprocessable_content

    # With a second owner, the first one may step down.
    signup("bob@example.com")
    add_member(owner, site, "bob@example.com", "owner")
    patch "#{path}/#{owner_id}", params: { member: { role: "viewer" } }, headers: owner, as: :json
    assert_response :ok
  end

  # --- Report: writing rows needs write access to the site ---

  test "only owners, editors and admins may add report rows for a site" do
    owner  = auth(signup("owner@example.com"))
    editor = auth(signup("editor@example.com"))
    viewer = auth(signup("viewer@example.com"))
    other  = auth(signup("other@example.com"))
    admin  = auth(signup("admin@example.com"))
    make_admin("admin@example.com")
    site = create_site(owner, "shop.example.com", "Shop")
    add_member(owner, site, "editor@example.com", "editor")
    add_member(owner, site, "viewer@example.com", "viewer")

    create_detail(owner,  site["id"], "2026-09", 10)
    create_detail(editor, site["id"], "2026-10", 20)
    create_detail(admin,  site["id"], "2026-11", 30)

    [ viewer, other ].each do |headers|
      post "/report/details", params: { detail: { site_id: site["id"], period: "2026-12", visits: 1 } },
                              headers: headers, as: :json
      assert_response :forbidden
    end
    assert_equal 3, Report::Detail.count
  end

  private

  def make_admin(email)
    System::User.find_by!(email: email).admin!
  end

  def add_member(headers, site, email, role)
    post "/website/sites/#{site['id']}/members", params: { member: { email: email, role: role } }, headers: headers, as: :json
    assert_response :created
  end
end
