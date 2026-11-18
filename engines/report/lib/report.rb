module Report
  # No `report_` table prefix: every module has its own database, so names cannot clash.
  # Defined BEFORE the engine is loaded, because `isolate_namespace` only adds its prefix when missing.
  def self.table_name_prefix = ""
end

require "report/engine"
