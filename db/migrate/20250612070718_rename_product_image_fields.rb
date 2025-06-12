class RenameProductImageFields < ActiveRecord::Migration[8.0]
  def change
    rename_column :products, :product_image, :main_image
    rename_column :products, :product_images, :supplementary_images
  end
end
