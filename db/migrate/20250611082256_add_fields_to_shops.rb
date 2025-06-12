class AddFieldsToShops < ActiveRecord::Migration[8.0]
  def change
    add_column :shops, :phone, :string
    add_column :shops, :location, :string
    add_column :shops, :image_url, :string

    add_column :shops, :item_description, :text
    add_column :shops, :item_price, :decimal, precision: 10, scale: 2
    add_column :shops, :item_image_urls, :json # Array stored as JSON

    add_column :shops, :pickup_agent, :string
    add_column :shops, :agreed, :boolean
  end
end
