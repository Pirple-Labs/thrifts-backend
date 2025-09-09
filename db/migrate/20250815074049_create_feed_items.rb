class CreateFeedItems < ActiveRecord::Migration[8.0]
  def change
    create_table :feed_items do |t|
      t.references :feed, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :section
      t.integer :position
      t.text :reason
      t.text :matched_phrase
      t.float :vec_score
      t.float :weight
      t.string :role
      t.float :final_score
      t.float :distance_km
      t.float :local_pop_z

      t.timestamps
    end
  end
end
