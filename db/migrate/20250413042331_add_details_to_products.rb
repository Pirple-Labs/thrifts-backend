class AddDetailsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :condition, :string
    add_column :products, :brand, :string
    add_column :products, :payment, :string
    add_column :products, :mode_of_delivery, :string
  end
end
