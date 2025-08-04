class DropModerationEvents < ActiveRecord::Migration[8.0]
  def change
    drop_table :moderation_events do |t|
      t.references :product, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string     :image_url
      t.string     :predicted_label
      t.float      :confidence
      t.string     :final_label
      t.boolean    :is_manual_override
      t.text       :notes
      t.timestamps
    end
  end
end
