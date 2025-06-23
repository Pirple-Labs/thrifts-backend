class CreateDeliveryAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :delivery_addresses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :nickname
      t.string :phone
      t.string :location
      t.string :pickup_agent

      t.timestamps
    end
  end
end
