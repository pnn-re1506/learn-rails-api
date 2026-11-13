class CreateSystemUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :system_users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false # has_secure_password stores the hashed password here
      t.timestamps
    end

    add_index :system_users, :email, unique: true # Guarantee unique emails at the DB level
  end
end
