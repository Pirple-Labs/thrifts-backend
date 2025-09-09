class CreateHintResolutions < ActiveRecord::Migration[8.0]
  def change
    create_table :hint_resolutions do |t|
      t.string :request_id, null: false
      t.string :page, null: false
      t.string :section_id, null: false
      t.text :hint_text, null: false
      t.bigint :resolved_type_id
      t.decimal :confidence, precision: 3, scale: 2
      t.string :locale, default: 'en'
      t.boolean :inventory_supported, default: false
      t.timestamps
    end
    
    add_index :hint_resolutions, [:request_id, :section_id]
    add_index :hint_resolutions, [:hint_text, :confidence]
    add_index :hint_resolutions, :created_at
  end
end
