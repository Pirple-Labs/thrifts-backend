class CreateRecommendedProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :recommended_products do |t|
      t.references :user, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :rank, default: 0
      t.text :reason
      t.timestamps
    end

    add_index :recommended_products, [:user_id, :product_id], unique: true
  end
end
