class MakeShopIdNotNullOnProducts < ActiveRecord::Migration[8.0]
  def change
    # Ensure shop_id is not null
    change_column_null :products, :shop_id, false

    # Add a foreign key constraint to ensure referential integrity
    add_foreign_key :products, :shops
  end
end
