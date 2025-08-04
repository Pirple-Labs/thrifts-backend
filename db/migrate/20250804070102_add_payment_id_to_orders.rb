class AddPaymentIdToOrders < ActiveRecord::Migration[8.0]
  def change
    add_reference :orders, :payment, null: false, foreign_key: true
  end
end
