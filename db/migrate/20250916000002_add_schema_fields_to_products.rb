class AddSchemaFieldsToProducts < ActiveRecord::Migration[8.0]
  def change
    # Add schema-related fields to products table
    add_column :products, :attributes, :jsonb, default: {}
    add_column :products, :schema_version, :string
    add_column :products, :status, :string, default: 'draft'
    
    # Create indexes for efficient querying
    add_index :products, :attributes, using: :gin
    add_index :products, :schema_version
    add_index :products, :status
    add_index :products, [:status, :schema_version]
  end
end
