module Report
  class Engine < ::Rails::Engine
    # Namespace `Report::`, table names have no prefix (see Report.table_name_prefix), e.g. `details`.
    isolate_namespace Report
  end
end
