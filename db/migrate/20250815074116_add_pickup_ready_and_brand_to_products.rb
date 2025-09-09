class AddPickupReadyAndBrandToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :pickup_ready, :boolean
    add_reference :products, :brand, null: true, foreign_key: true
  end
end
