# db/migrate/XXXXXXXXXXXXXX_harden_payments_for_mpesa_stk.rb
class HardenPaymentsForMpesaStk < ActiveRecord::Migration[8.0]
  def up
    # Whole-KES integer amount (keeps your decimal column for now)
    add_column :payments, :amount, :integer

    # Backfill amount from existing decimal total_amount (rounded to nearest KES)
    execute <<~SQL.squish
      UPDATE payments
      SET amount = ROUND(COALESCE(total_amount, 0));
    SQL

    change_column_null :payments, :amount, false, 0

    # Extra fields to fully track STK init + callback
    add_column :payments, :gateway, :string, null: false, default: "mpesa"
    add_column :payments, :mpesa_merchant_request_id, :string
    add_column :payments, :result_code, :integer
    add_column :payments, :result_desc, :string
    add_column :payments, :checkout_key, :string
    add_column :payments, :raw_callback, :text

    # Helpful indexes
    add_index :payments, :mpesa_checkout_request_id unless index_exists?(:payments, :mpesa_checkout_request_id)
    add_index :payments, :checkout_key, unique: true unless index_exists?(:payments, :checkout_key)

    # Ensure referential integrity for orders → payments
    add_foreign_key :orders, :payments unless foreign_key_exists?(:orders, :payments)
  end

  def down
    remove_foreign_key :orders, :payments if foreign_key_exists?(:orders, :payments)

    remove_index :payments, :checkout_key if index_exists?(:payments, :checkout_key)
    remove_index :payments, :mpesa_checkout_request_id if index_exists?(:payments, :mpesa_checkout_request_id)

    remove_column :payments, :raw_callback if column_exists?(:payments, :raw_callback)
    remove_column :payments, :checkout_key if column_exists?(:payments, :checkout_key)
    remove_column :payments, :result_desc if column_exists?(:payments, :result_desc)
    remove_column :payments, :result_code if column_exists?(:payments, :result_code)
    remove_column :payments, :mpesa_merchant_request_id if column_exists?(:payments, :mpesa_merchant_request_id)
    remove_column :payments, :gateway if column_exists?(:payments, :gateway)
    remove_column :payments, :amount if column_exists?(:payments, :amount)
  end
end
