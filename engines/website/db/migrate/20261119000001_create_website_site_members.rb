class CreateWebsiteSiteMembers < ActiveRecord::Migration[8.1]
  def change
    # Who may do what on ONE site (resource-level permissions).
    # Lives in the website database because sites belong to the Website module.
    create_table :site_members do |t|
      t.references :site, null: false, foreign_key: true   # same database -> a real foreign key is possible
      t.bigint :user_id, null: false                       # System::User lives in another database: no foreign key
      t.integer :role, null: false, default: 0             # 0 = viewer, 1 = editor, 2 = owner
      t.timestamps
    end

    add_index :site_members, %i[site_id user_id], unique: true   # one membership per user per site
    add_index :site_members, :user_id                            # "which sites can this user see?"
  end
end
