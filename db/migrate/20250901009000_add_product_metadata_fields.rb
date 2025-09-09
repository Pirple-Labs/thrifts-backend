class AddProductMetadataFields < ActiveRecord::Migration[8.0]
  def change
    # Add missing product metadata fields for intelligent shopping assistant
    add_column :products, :subcategory, :string
    add_column :products, :material, :string
    add_column :products, :style, :string
    add_column :products, :use_case, :string
    add_column :products, :specifications, :jsonb, default: {}
    add_column :products, :seasonality, :string
    
    # Add brand metadata fields
    add_column :brands, :category, :string  # premium, budget, luxury
    add_column :brands, :specialization, :string  # tech, fashion, home
    add_column :brands, :description, :text
    
    # Create indexes for efficient querying
    add_index :products, :subcategory
    add_index :products, :material
    add_index :products, :style
    add_index :products, :use_case
    add_index :products, :specifications, using: :gin
    add_index :products, :seasonality
    
    add_index :brands, :category
    add_index :brands, :specialization
  end
end

