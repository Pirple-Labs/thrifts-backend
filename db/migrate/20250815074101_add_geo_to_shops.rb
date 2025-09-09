class AddGeoToShops < ActiveRecord::Migration[8.0]
  def change
    add_column :shops, :lat, :decimal
    add_column :shops, :lon, :decimal
    add_column :shops, :geohash6, :string
  end
end
