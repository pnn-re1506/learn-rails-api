# "Front door" #2 of the Website module for other modules (approach 1: cross-database SQL JOIN).
#
# All three databases live on the SAME MySQL server, and in MySQL a "database" is just a schema,
# so one connection can read another database's table by writing `database`.`table`.
# Report runs ONE query on its own connection and joins this table into it.
#
# The knowledge of "which database and which table" stays here, in the module that owns the table.
# Report only calls these methods; it never writes `website_dev` or `website_sites` itself.
module Website
  module ReportJoin
    # `website_dev`.`website_sites` (the database name differs per environment: _dev, _test...)
    def self.sites_table
      conn = Site.lease_connection
      [ Site.connection_db_config.database, Site.table_name ].map { |name| conn.quote_table_name(name) }.join(".")
    end

    # LEFT JOIN keeps report rows whose site was deleted (site columns are then NULL),
    # because there is no foreign key between two databases.
    # `fk_column` is the column of the calling table that holds the site id, e.g. "report_details.site_id".
    def self.left_join_sql(fk_column)
      "LEFT JOIN #{sites_table} ON #{sites_table}.id = #{fk_column}"
    end

    def self.domain_column
      "#{sites_table}.domain"
    end

    def self.name_column
      "#{sites_table}.name"
    end

    # Columns to add to the SELECT, aliased so they appear as `site_domain` / `site_name` on the record.
    def self.select_sql
      "#{sites_table}.id AS site_ref_id, #{domain_column} AS site_domain, #{name_column} AS site_name"
    end
  end
end
