class AddModerationFieldsToProducts < ActiveRecord::Migration[8.0]
    def change
    add_column :products, :moderation_status, :string, default: "pending"
    add_column :products, :moderation_label, :string
    add_column :products, :moderation_confidence, :float
  end
end
