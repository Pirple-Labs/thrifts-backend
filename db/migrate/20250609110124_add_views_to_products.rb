class AddViewsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :views, :integer
  end
end
