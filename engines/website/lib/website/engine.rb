module Website
  class Engine < ::Rails::Engine
    # Namespace `Website::`, table names have no prefix (see Website.table_name_prefix), e.g. `sites`.
    isolate_namespace Website
  end
end
