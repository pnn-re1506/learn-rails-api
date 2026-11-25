require "test_helper"

# Keeps Swagger (config/openapi.yml) honest: it must describe exactly the routes the app really has.
class DocsTest < ActionDispatch::IntegrationTest
  ENGINES = { "/system" => System::Engine, "/website" => Website::Engine, "/report" => Report::Engine }.freeze

  test "swagger ui page is public" do
    get "/api-docs"
    assert_response :ok
    assert_includes response.body, "swagger-ui"
  end

  test "openapi file is served as valid openapi 3" do
    get "/api-docs/openapi.yml"
    assert_response :ok

    spec = YAML.safe_load(response.body)
    assert_equal "3.0.3", spec["openapi"]
    assert spec["paths"].any?
  end

  test "every real route is documented in openapi.yml" do
    missing = real_operations - documented_operations
    assert_empty missing, "Routes missing from config/openapi.yml: #{missing.sort.join(', ')}"
  end

  test "openapi.yml documents no route that does not exist" do
    extra = documented_operations - real_operations - [ "GET /up" ]
    assert_empty extra, "config/openapi.yml documents unknown routes: #{extra.sort.join(', ')}"
  end

  test "every operation documents responses and a tag (except health check)" do
    spec_paths.each do |path, item|
      item.slice("get", "post", "patch", "put", "delete").each do |verb, op|
        assert op["responses"].present?, "#{verb.upcase} #{path} has no responses"
        assert op["tags"].present?, "#{verb.upcase} #{path} has no tags" unless path == "/up"
      end
    end
  end

  private

  def spec_paths
    @spec_paths ||= YAML.load_file(Rails.root.join("config/openapi.yml"))["paths"]
  end

  # "GET /website/sites/{id}" for every operation in the file
  def documented_operations
    spec_paths.flat_map do |path, item|
      item.keys.grep(/\A(get|post|patch|put|delete)\z/).map { |verb| "#{verb.upcase} #{path}" }
    end
  end

  # Same format, built from the engines' routes.
  def real_operations
    ENGINES.flat_map do |prefix, engine|
      engine.routes.routes.filter_map do |route|
        verb = route.verb.to_s
        next if verb.blank? || verb == "PUT"   # Rails adds PUT as an alias of PATCH; document PATCH only

        path = route.path.spec.to_s.delete_suffix("(.:format)").gsub(/:(\w+)/, '{\1}')
        "#{verb} #{prefix}#{path}"
      end
    end
  end
end
