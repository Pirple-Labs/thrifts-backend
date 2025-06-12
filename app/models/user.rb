class User < ApplicationRecord
  # Associations
  has_many :shops, dependent: :destroy
  has_many :wishlist_items, dependent: :destroy
  has_many :cart_items, dependent: :destroy
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
