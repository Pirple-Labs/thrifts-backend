class AddGoogleAuthToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :name, :string
    add_column :users, :google_id, :string
    add_column :users, :avatar, :string
  end
end
