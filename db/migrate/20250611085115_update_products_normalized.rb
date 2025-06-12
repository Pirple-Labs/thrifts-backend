class UpdateProductsNormalized < ActiveRecord::Migration[8.0]
 def change
    change_table :products do |t|
      t.references :shop, null: true
      t.references :brand, foreign_key: true
      t.references :condition, foreign_key: true
      t.references :payment_method, foreign_key: true
      t.references :delivery_mode, foreign_key: true

      t.remove :store_logo
      t.remove :brand
      t.remove :condition
      t.remove :payment
      t.remove :mode_of_delivery
    end
  end
end
