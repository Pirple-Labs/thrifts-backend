class ChangeUserIdNullableInModerationEvents < ActiveRecord::Migration[8.0]
  def change
    change_column_null :moderation_events, :user_id, true
  end
end
