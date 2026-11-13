class CreateReportSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :report_snapshots do |t|
      # No foreign key: users live in another database (System / MySQL)
      t.bigint :user_id, null: false
      t.string :title, null: false
      t.jsonb :data, null: false, default: []  # Copy of the analysis summary at creation time
      t.timestamps
    end

    add_index :report_snapshots, :user_id
  end
end
