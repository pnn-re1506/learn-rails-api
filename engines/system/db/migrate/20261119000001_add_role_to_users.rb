class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    # Global role of a user in the whole system (see System::User#role):
    #   0 = member (default, everyone who signs up), 1 = admin
    # Stored as an integer; the enum in the model maps it to a name.
    add_column :users, :role, :integer, null: false, default: 0
  end
end
