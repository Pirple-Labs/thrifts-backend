class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, 
         :confirmable,
         jwt_revocation_strategy: JwtDenylist
end
