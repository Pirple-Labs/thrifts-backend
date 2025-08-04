class AddModerationReasonToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :moderation_reason, :text
  end
end
