class CreateFeeds < ActiveRecord::Migration[8.0]
  def change
    create_table :feeds do |t|
      t.string :feed_uid
      t.references :user, null: false, foreign_key: true
      t.string :session_id
      t.string :page
      t.string :intent_label
      t.float :intent_confidence
      t.jsonb :constraints
      t.integer :ttl_seconds
      t.boolean :is_cache_hit
      t.string :prompt_version
      t.string :model_version
      t.string :index_version
      t.string :fingerprint

      t.timestamps
    end
  end
end
