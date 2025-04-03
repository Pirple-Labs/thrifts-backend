class Api::AuthController < ApplicationController
  skip_before_action :verify_authenticity_token 
  require 'jwt'
  require 'google-id-token'  # ✅ Import Google ID Token verifier

  def google_login
    Rails.logger.info "Received Google Auth Request: #{params.inspect}" # Debugging Log

    # ✅ Verify Google ID token
    validator = GoogleIDToken::Validator.new
    begin
      payload = validator.check(params[:id_token], ENV['GOOGLE_CLIENT_ID'])
      unless payload
        Rails.logger.error "Invalid Google Token"
        return render json: { error: "Invalid Google Token" }, status: :unauthorized
      end
    rescue StandardError => e
      Rails.logger.error "Google Token Verification Failed: #{e.message}"
      return render json: { error: "Invalid Google Token" }, status: :unauthorized
    end

    Rails.logger.info "Google Token Verified: #{payload.inspect}"

    # ✅ Extract user info from verified Google payload
    user_info = {
      email: payload['email'],
      name: payload['name'],
      google_id: payload['sub'], # Google’s unique user ID
      avatar: payload['picture']
    }

    user = User.find_or_initialize_by(email: user_info[:email])

    if user.new_record?
      user.name = user_info[:name]
      user.google_id = user_info[:google_id]
      user.avatar = user_info[:avatar]
      user.password = Devise.friendly_token[0, 20]  # ✅ Generate a random secure password
      user.save!
      Rails.logger.info "New user created: #{user.inspect}"
    else
      Rails.logger.info "Existing user found: #{user.inspect}"
    end

    token = generate_jwt(user)
    Rails.logger.info "JWT Token Generated: #{token}"

    render json: { user: user, token: token }
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "User creation failed: #{e.record.errors.full_messages}"
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def generate_jwt(user)
    payload = { user_id: user.id, exp: 24.hours.from_now.to_i }
    JWT.encode(payload, Rails.application.credentials.secret_key_base)
  end
end
