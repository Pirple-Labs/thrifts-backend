# frozen_string_literal: true

class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.string   :event_id,       null: false                # idempotency key from client
      t.references :user,         null: true, foreign_key: true
      t.string   :anonymous_id,   null: true
      t.string   :session_id,     null: false
      t.string   :event_name,     null: false                # e.g., feed_rendered, product_clicked
      t.datetime :timestamp_utc,  null: false                # client-sent UTC timestamp
      t.datetime :received_at,    null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.string   :page,           null: false                # home|pdp|profile|cart|checkout
      t.string   :region,         null: false
      t.string   :geohash6,       null: true
      t.string   :schema_version, null: false, default: "v1"
      t.jsonb    :payload,        null: false, default: {}   # small per-event body
    end

    add_index :events, :event_id, unique: true
    add_index :events, [:user_id, :session_id, :timestamp_utc], name: "index_events_on_user_session_time"
    add_index :events, [:event_name, :timestamp_utc],           name: "index_events_on_name_time"
    execute <<~SQL
      CREATE INDEX index_events_on_payload_gin ON events USING GIN (payload);
    SQL
  end
end
