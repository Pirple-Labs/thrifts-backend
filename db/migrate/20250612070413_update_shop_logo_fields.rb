class UpdateShopLogoFields < ActiveRecord::Migration[8.0]
 def change
    remove_column :shops, :image_url, :string
    rename_column :shops, :store_logo, :store_logo_url
  end
end
