class CreateReportDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :report_details do |t|
      # No foreign keys: users live in the System database, sites in the Website database
      t.bigint :user_id, null: false
      t.bigint :site_id, null: false              # id of a Website::Site
      t.string :period, null: false               # month, e.g. "2026-10"
      t.integer :visits, null: false, default: 0
      t.integer :page_views, null: false, default: 0
      t.decimal :bounce_rate, precision: 5, scale: 2, null: false, default: 0  # percent
      t.timestamps
    end

    add_index :report_details, %i[user_id site_id period], unique: true
    add_index :report_details, :site_id
  end
end
