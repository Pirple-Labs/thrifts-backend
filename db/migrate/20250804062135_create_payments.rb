class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :user, null: false, foreign_key: true

      t.decimal :total_amount, precision: 10, scale: 2, null: false
      t.string :status, default: "pending", null: false  # pending, completed, failed

      # M-Pesa metadata
      t.string :mpesa_checkout_request_id
      t.string :mpesa_receipt_number
      t.string :phone_number_used
      t.datetime :completed_at

      t.timestamps
    end
  end
end
