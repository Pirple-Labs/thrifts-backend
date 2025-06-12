class ChangeQuantityDefaultInCartItems < ActiveRecord::Migration[8.0]
  def change
    change_column_default :cart_items, :quantity, from: nil, to: 1
  end
  def up
  change_column_default :cart_items, :quantity, 1
  CartItem.where(quantity: nil).update_all(quantity: 1)
  end

  def down
  change_column_default :cart_items, :quantity, nil
  end

end
