class CreateWithdrawalRequests < ActiveRecord::Migration[8.0]
    def change
    create_table :withdrawal_requests do |t|
      t.references :merchant_wallet, null: false, foreign_key: true

      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :status, default: "requested", null: false  # requested, processing, completed, failed

      # M-Pesa B2C metadata (for payout tracking)
      t.string :mpesa_conversation_id
      t.string :mpesa_receipt_number
      t.string :phone_number
      t.datetime :completed_at

      t.timestamps
    end
  end
end
