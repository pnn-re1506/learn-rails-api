# Report's window onto the Website module: a FEDERATED table `sites` in the REPORT database.
# It stores no data. Each query on it is forwarded to the table `sites` on the WEBSITE server,
# so Report can JOIN it like a local table (see Website::ReportJoin).
#
# Run the Website migrations first: the remote table must exist when this runs.
# The columns must match Website's `sites` table (engines/website/db/migrate).
#
# The address of the website server is stored once in a MySQL SERVER object, so the table
# definition (and `SHOW CREATE TABLE`) does not contain the password.
# Host/port are the ones the REPORT SERVER uses to reach the website server, which is not always
# the ones Rails uses (e.g. Rails on your machine -> localhost:3308, but report MySQL in Docker ->
# mysql-website:3306). Override with WEBSITE_FEDERATED_HOST / WEBSITE_FEDERATED_PORT.
class CreateFederatedSites < ActiveRecord::Migration[8.1]
  def up
    execute "DROP SERVER IF EXISTS #{server_name}"
    execute <<~SQL.squish
      CREATE SERVER #{server_name} FOREIGN DATA WRAPPER mysql OPTIONS (
        HOST #{quote(website[:host])}, PORT #{Integer(website[:port])},
        USER #{quote(website[:username])}, PASSWORD #{quote(website[:password])},
        DATABASE #{quote(website[:database])}
      )
    SQL

    create_table :sites, options: "ENGINE=FEDERATED CONNECTION='#{server_name}/sites'" do |t|
      t.string :domain, null: false
      t.string :name, null: false
      t.timestamps
    end
  end

  def down
    drop_table :sites
    execute "DROP SERVER IF EXISTS #{server_name}"
  end

  private

  # One SERVER object per environment: development and test share the same report MySQL server.
  # `db:prepare` in development also migrates the TEST database, so use the environment of the
  # database being migrated, not Rails.env.
  def server_name
    "website_#{env_name}"
  end

  def env_name
    connection.pool.db_config.env_name
  end

  def website
    @website ||= begin
      config = ActiveRecord::Base.configurations.configs_for(env_name: env_name, name: "website").configuration_hash
      config.merge(host: ENV.fetch("WEBSITE_FEDERATED_HOST", config[:host]),
                   port: ENV.fetch("WEBSITE_FEDERATED_PORT", config[:port]))
    end
  end

  def quote(value)
    connection.quote(value.to_s)
  end
end
