class MakeUserIdOptionalInFeeds < ActiveRecord::Migration[7.0]
  def change
    change_column_null :feeds, :user_id, true
    remove_foreign_key :feeds, :users, if_exists: true
    add_foreign_key :feeds, :users, on_delete: :nullify, if_not_exists: true
  end
end
