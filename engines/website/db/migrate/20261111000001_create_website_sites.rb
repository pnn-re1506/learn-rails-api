class CreateWebsiteSites < ActiveRecord::Migration[8.1]
  def change
    create_table :website_sites do |t|
      t.string :domain, null: false
      t.string :name, null: false
      t.timestamps
    end

    add_index :website_sites, :domain, unique: true
  end
end
