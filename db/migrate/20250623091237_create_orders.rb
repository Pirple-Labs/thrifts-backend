class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, default: "pending"
      t.integer :total_items, default: 0
      t.decimal :total_price, precision: 10, scale: 2, default: 0.0

      t.timestamps
    end
  end
end
