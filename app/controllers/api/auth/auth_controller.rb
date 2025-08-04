# app/controllers/api/auth/auth_controller.rb

require 'google-id-token'

module Api
  module Auth
    class AuthController < Api::BaseController
      skip_before_action :authenticate_user!, only: [:manual_login, :google_login, :signup]
    #   skip_before_action :verify_authenticity_token, only: [:manual_login, :google_login, :signup]

      # POST /api/auth/manual_login
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

      # POST /api/auth/google_login
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

        # 🚫 Cloudinary logic removed — handled by frontend now

        sign_in(user)
        token = request.env['warden-jwt_auth.token']
        render json: { user: user, token: token }
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # POST /api/auth/signup
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
end
