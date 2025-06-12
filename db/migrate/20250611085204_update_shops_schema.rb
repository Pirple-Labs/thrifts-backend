class UpdateShopsSchema < ActiveRecord::Migration[8.0]
   def change
    change_table :shops do |t|
      t.string :store_logo

      t.remove :item_description
      t.remove :item_price
      t.remove :item_image_urls
    end
  end
end
