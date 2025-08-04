class CreateMerchantPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :merchant_payments do |t|
      t.references :payment, null: false, foreign_key: true
      t.references :shop, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true

      t.decimal :amount, precision: 10, scale: 2, null: false

      t.string :status, default: "escrowed", null: false  # escrowed, released, transferred
      t.datetime :escrowed_at
      t.datetime :released_at
      t.datetime :transferred_at

      t.timestamps
    end
  end
end
