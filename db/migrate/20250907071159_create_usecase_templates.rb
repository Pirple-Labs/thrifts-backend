class CreateUsecaseTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :usecase_templates do |t|
      t.text :template_id, null: false # e.g., 'laptop_setup'
      t.text :name, null: false
      t.jsonb :slots, default: [] # ["stand","mouse","bag","hub","monitor"]
      t.jsonb :rules, default: {} # caps/diversity, price band hints, etc.
      t.timestamps
    end
    
    add_index :usecase_templates, :template_id, unique: true
  end
end
