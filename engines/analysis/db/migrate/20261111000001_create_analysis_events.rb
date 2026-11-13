class CreateAnalysisEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_events do |t|
      # No foreign key: users live in another database (System / MySQL)
      t.bigint :user_id, null: false
      t.string :name, null: false
      t.integer :value, null: false, default: 0
      t.timestamps
    end

    add_index :analysis_events, %i[user_id name]
  end
end
