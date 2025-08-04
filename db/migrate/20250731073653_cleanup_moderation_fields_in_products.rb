class CleanupModerationFieldsInProducts < ActiveRecord::Migration[8.0]
  def change
    remove_column :products, :moderation_status, :string if column_exists?(:products, :moderation_status)
    remove_column :products, :final_label, :string if column_exists?(:products, :final_label)
    remove_column :products, :is_manual_override, :boolean if column_exists?(:products, :is_manual_override)
  end
end
