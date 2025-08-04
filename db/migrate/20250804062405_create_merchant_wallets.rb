class CreateMerchantWallets < ActiveRecord::Migration[8.0]
  def change
    create_table :merchant_wallets do |t|
      t.references :shop, null: false, foreign_key: true, index: { unique: true }

      t.decimal :balance, precision: 10, scale: 2, default: 0.0, null: false

      t.timestamps
    end
  end
end
