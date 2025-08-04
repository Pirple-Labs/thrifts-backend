class AddModerationStatusToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :moderation_status, :string, default: "pending"
  end
end
