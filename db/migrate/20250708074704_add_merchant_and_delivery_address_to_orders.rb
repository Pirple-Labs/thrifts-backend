class AddMerchantAndDeliveryAddressToOrders < ActiveRecord::Migration[8.0]
  def change
    add_reference :orders, :shop, null: false, foreign_key: true
    add_reference :orders, :delivery_address, null: false, foreign_key: true
  end
end
