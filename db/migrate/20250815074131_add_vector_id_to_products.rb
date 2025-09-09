class AddVectorIdToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :vector_id, :string
  end
end
