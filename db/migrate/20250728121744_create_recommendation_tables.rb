class CreateRecommendationTables < ActiveRecord::Migration[8.0]
  def change
    create_table :similar_products do |t|
      t.references :product, null: false, foreign_key: true
      t.bigint     :similar_product_id, null: false
      t.float      :score
      t.timestamps
    end
    add_foreign_key :similar_products, :products, column: :similar_product_id

    create_table :complementary_products do |t|
      t.references :product, null: false, foreign_key: true
      t.bigint     :complementary_product_id, null: false
      t.string     :triggered_by
      t.float      :score
      t.timestamps
    end
    add_foreign_key :complementary_products, :products, column: :complementary_product_id
  end
end
