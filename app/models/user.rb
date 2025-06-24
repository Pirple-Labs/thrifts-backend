class User < ApplicationRecord
  # Associations
has_one :shop, dependent: :destroy
has_many :products, through: :shop

has_many :wishlist_items, dependent: :destroy
has_many :wishlist_products, through: :wishlist_items, source: :product

has_many :cart_items, dependent: :destroy
has_many :cart_products, through: :cart_items, source: :product

has_many :recommended_products, dependent: :destroy
has_many :recommended_products_list, through: :recommended_products, source: :product

has_many :orders, dependent: :destroy
has_many :delivery_addresses, dependent: :destroy
  # Role management
  # enum role: { user: 0, merchant: 1, admin: 2 }

  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable,
        #  :confirmable,
         jwt_revocation_strategy: JwtDenylist

  # Callback (optional safety)
  after_initialize :set_default_role, if: :new_record?

  private

  def set_default_role
    self.role ||= :user
  end
end
