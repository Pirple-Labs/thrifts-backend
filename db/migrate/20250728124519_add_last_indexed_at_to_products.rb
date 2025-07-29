class AddLastIndexedAtToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :last_indexed_at, :datetime
  end
end
