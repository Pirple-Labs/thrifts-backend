class AddProductImagesToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :product_images, :jsonb
  end
end
