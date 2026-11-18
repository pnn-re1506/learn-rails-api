# "Front door" #2 of the Website module for other modules (approach 1: SQL JOIN through FEDERATED).
#
# Website lives on its OWN MySQL server (another port, possibly another machine), so Report's
# connection cannot reach it directly. Instead the report database holds a FEDERATED table with
# the same name as Website's table (`sites`, see the report migration CreateFederatedSites):
# it stores nothing, MySQL forwards each read to the website server.
# For Report that table is local, so it runs ONE query on its own connection and JOINs `sites` into it.
#
# The knowledge of "which table and which columns" stays here, in the module that owns the table.
# Report only calls these methods; it never writes `sites` itself.
module Website
  module ReportJoin
    # `sites`: the federated table in the report database. Same name as Website's own table.
    def self.sites_table
      Site.lease_connection.quote_table_name(Site.table_name)
    end

    # LEFT JOIN keeps report rows whose site was deleted (site columns are then NULL),
    # because there is no foreign key between two databases.
    # `fk_column` is the column of the calling table that holds the site id, e.g. "details.site_id".
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
