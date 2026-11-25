# API documentation (no login needed):
#   GET /api-docs               Swagger UI (loaded from a CDN, so no gem is required)
#   GET /api-docs/openapi.yml   the OpenAPI 3 file that Swagger UI reads: config/openapi.yml
class DocsController < ActionController::API
  SWAGGER_UI = <<~HTML.freeze
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8">
        <title>learn-rails-api - API docs</title>
        <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
      </head>
      <body>
        <div id="swagger-ui"></div>
        <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
        <script>
          SwaggerUIBundle({ url: "/api-docs/openapi.yml", dom_id: "#swagger-ui", persistAuthorization: true });
        </script>
      </body>
    </html>
  HTML

  def show
    render html: SWAGGER_UI.html_safe, layout: false
  end

  def spec
    send_file Rails.root.join("config/openapi.yml"), type: "text/yaml", disposition: "inline"
  end
end
