module Report
  class Engine < ::Rails::Engine
    # Namespace `Report::`, table names get the `report_` prefix (e.g. report_snapshots).
    isolate_namespace Report
  end
end
