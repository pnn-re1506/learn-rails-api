module Website
  class Engine < ::Rails::Engine
    # Namespace `Website::`, table names get the `website_` prefix (e.g. website_sites).
    isolate_namespace Website
  end
end
