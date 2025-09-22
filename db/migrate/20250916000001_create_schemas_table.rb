class CreateSchemasTable < ActiveRecord::Migration[8.0]
  def change
    create_table :schemas, id: false do |t|
      t.string :id, null: false, primary_key: true  # e.g., "fashion.v1"
      t.string :category, null: false               # e.g., "fashion"
      t.jsonb :schema_json, null: false             # Field definitions
      t.string :version, null: false                # e.g., "v1"
      t.boolean :active, default: true              # Enable/disable schemas
      t.text :description                           # Human-readable description
      t.timestamps
    end

    add_index :schemas, :category
    add_index :schemas, :active
    add_index :schemas, :schema_json, using: :gin
  end
end
