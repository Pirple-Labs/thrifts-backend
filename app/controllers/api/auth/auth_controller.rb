# app/controllers/api/auth/auth_controller.rb
require 'google-id-token'

module Api
  module Auth
    class AuthController < Api::BaseController
      # Public endpoints for token issuance
      skip_before_action :authenticate_user!, only: [:manual_login, :google_login, :signup], raise: false

      # POST /api/auth/manual_login
      # Body: { email, password }
      def manual_login
        email = params[:email].to_s.strip.downcase
        password = params[:password].to_s

        return render json: { error: 'Email and password are required' }, status: :bad_request if email.blank? || password.blank?

        user = User.find_for_database_authentication(email: email)
        unless user&.valid_password?(password)
          return render json: { error: 'Invalid credentials' }, status: :unauthorized
        end

        sign_in(user) # devise-jwt will dispatch the token
        token = request.env['warden-jwt_auth.token']
        response.set_header('Authorization', "Bearer #{token}") if token.present?

        render json: { user: user_json(user), token: token }, status: :ok
      rescue => e
        Rails.logger.error("[manual_login] #{e.class}: #{e.message}")
        render json: { error: 'login_failed' }, status: :internal_server_error
      end

      # POST /api/auth/google_login
      # Body: { id_token }
      def google_login
        id_token = params[:id_token].to_s
        return render json: { error: 'id_token is required' }, status: :bad_request if id_token.blank?

        validator = GoogleIDToken::Validator.new
        audiences = ENV.fetch('GOOGLE_CLIENT_ID', '').split(',').map(&:strip).reject(&:blank?)
        return render json: { error: 'Server missing GOOGLE_CLIENT_ID' }, status: :internal_server_error if audiences.empty?

        payload = nil
        last_err = nil
        audiences.each do |aud|
          begin
            # validator.check(token, required_audience)
            payload = validator.check(id_token, aud)
            break if payload.present?
          rescue StandardError => e
            last_err = e
            next
          end
        end

        return render json: { error: "Invalid Google Token#{last_err ? ": #{last_err.message}" : ''}" }, status: :unauthorized unless payload

        email = payload['email'].to_s.downcase
        name  = payload['name'].presence
        gid   = payload['sub'].to_s

        user = User.find_or_initialize_by(email: email)
        if user.new_record?
          user.name      = name if name.present?
          user.password  = Devise.friendly_token[0, 20]
          user.google_id = gid if user.respond_to?(:google_id=)
          user.save!
        else
          # keep google_id up to date if you store it
          user.update(google_id: gid) if user.respond_to?(:google_id=) && user.google_id.blank?
        end

        sign_in(user) # devise-jwt dispatch
        token = request.env['warden-jwt_auth.token']
        response.set_header('Authorization', "Bearer #{token}") if token.present?

        render json: { user: user_json(user), token: token }, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      rescue => e
        Rails.logger.error("[google_login] #{e.class}: #{e.message}")
        render json: { error: 'google_login_failed' }, status: :internal_server_error
      end

      # POST /api/auth/signup
      # Body: { user: { email, password, password_confirmation, name } }
      def signup
        attrs = signup_params
        attrs[:email] = attrs[:email].to_s.strip.downcase

        user = User.new(attrs)
        if user.save
          sign_in(user) # devise-jwt dispatch
          token = request.env['warden-jwt_auth.token']
          response.set_header('Authorization', "Bearer #{token}") if token.present?
          render json: { user: user_json(user), token: token }, status: :created
        else
          render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error("[signup] #{e.class}: #{e.message}")
        render json: { error: 'signup_failed' }, status: :internal_server_error
      end

      # DELETE /api/auth/logout
      # Requires Authorization: Bearer <jwt> — devise-jwt will revoke via denylist
      def logout
        if current_user
          sign_out(current_user)
        end
        head :no_content
      end

      private

      def signup_params
        params.require(:user).permit(:email, :password, :password_confirmation, :name)
      end

      # Never leak sensitive columns
      def user_json(user)
        {
          id: user.id,
          email: user.email,
          name: user.name
        }
      end
    end
  end
end
