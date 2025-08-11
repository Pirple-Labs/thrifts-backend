require 'cloudinary'

module Api
  class AuthController < Api::BaseController
    skip_before_action :authenticate_user!, only: [:manual_login, :google_login, :signup]
    require 'google-id-token'

    # ✅ Manual Email + Password Login
    def manual_login
      user = User.find_by(email: params[:email])

      if user&.valid_password?(params[:password])
        sign_in(user)
        token = request.env['warden-jwt_auth.token']
        render json: { user: user, token: token }, status: :ok
      else
        render json: { error: 'Invalid credentials' }, status: :unauthorized
      end
    end

    # ✅ Google OAuth Login
    def google_login
      validator = GoogleIDToken::Validator.new

      begin
        payload = validator.check(params[:id_token], ENV['GOOGLE_CLIENT_ID'])
        return render json: { error: "Invalid Google Token" }, status: :unauthorized unless payload
      rescue StandardError => e
        return render json: { error: "Invalid Google Token: #{e.message}" }, status: :unauthorized
      end

      user = User.find_or_initialize_by(email: payload['email'])

      if user.new_record?
        user.name = payload['name']
        user.google_id = payload['sub']
        user.password = Devise.friendly_token[0, 20]
        user.save!
      end

      # ✅ Upload avatar to Cloudinary if still Google-hosted
      if user.avatar.blank? || user.avatar.include?("googleusercontent")
        begin
          upload = Cloudinary::Uploader.upload(
            payload['picture'],
            folder: "thrifts/avatars/#{user.id}"
          )
          user.update!(avatar: upload["secure_url"])
        rescue => e
          Rails.logger.warn("Cloudinary upload failed: #{e.message}")
          # You can skip or notify but don’t block login for this
        end
      end

      sign_in(user)
      token = request.env['warden-jwt_auth.token']
      render json: { user: user, token: token }
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
    end

    # ✅ Signup
    def signup
      user = User.new(signup_params)

      if user.save
        sign_in(user)
        token = request.env['warden-jwt_auth.token']
        render json: { user: user, token: token }
      else
        render json: { error: user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def signup_params
      params.require(:user).permit(:email, :password, :password_confirmation, :name)
    end
  end
end
