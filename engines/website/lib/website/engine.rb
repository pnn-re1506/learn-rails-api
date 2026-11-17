module Analysis
  class Engine < ::Rails::Engine
    # Namespace `Analysis::`, table names get the `analysis_` prefix (e.g. analysis_events).
    isolate_namespace Analysis
  end
end
