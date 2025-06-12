class CreateReferenceTables < ActiveRecord::Migration[8.0]
    def change
    create_table :brands do |t|
      t.string :name, null: false
      t.timestamps
    end

    create_table :conditions do |t|
      t.string :name, null: false
      t.timestamps
    end

    create_table :payment_methods do |t|
      t.string :name, null: false
      t.timestamps
    end

    create_table :delivery_modes do |t|
      t.string :name, null: false
      t.timestamps
    end
  end
end
