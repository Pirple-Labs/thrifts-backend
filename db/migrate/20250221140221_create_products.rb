class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name
      t.string :store_logo
      t.string :product_image
      t.decimal :price
      t.text :description

      t.timestamps
    end
  end
end
