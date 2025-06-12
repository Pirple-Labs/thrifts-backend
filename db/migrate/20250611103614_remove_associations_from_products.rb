class RemoveAssociationsFromProducts < ActiveRecord::Migration[8.0]
  def change
    remove_reference :products, :brand, foreign_key: true
    remove_reference :products, :condition, foreign_key: true
    remove_reference :products, :payment_method, foreign_key: true
    remove_reference :products, :delivery_mode, foreign_key: true
  end
end
