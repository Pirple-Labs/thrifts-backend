class Api::AuthController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, only: [:manual_login, :google_login, :signup]
  require 'jwt'
  require 'google-id-token'

  # 🔐 Manual Email + Password Login
  def manual_login
    user = User.find_by(email: params[:email])

    # Use Devise's valid_password? method to authenticate
    if user&.valid_password?(params[:password])
      # Generate JWT token
      token = generate_jwt(user)
      
      # Send user and token in the response
      render json: { user: user, token: token }, status: :ok
    else
      render json: { error: 'Invalid credentials' }, status: :unauthorized
    end
  end
  

  # 🔐 Google OAuth Login
  def google_login
    Rails.logger.info "Received Google Auth Request: #{params.inspect}"

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

    user_info = {
      email: payload['email'],
      name: payload['name'],
      google_id: payload['sub'],
      avatar: payload['picture']
    }

    user = User.find_or_initialize_by(email: user_info[:email])

    if user.new_record?
      user.name = user_info[:name]
      user.google_id = user_info[:google_id]
      user.avatar = user_info[:avatar]
      user.password = Devise.friendly_token[0, 20]
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

  # 🔐 User Sign Up
  def signup
    user = User.new(signup_params)

    if user.save
      token = generate_jwt(user)
      render json: { user: user, token: token }
    else
      render json: { error: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # Strong Parameters for Signup
  def signup_params
    params.require(:user).permit(:email, :password, :password_confirmation, :name)
  end

  # Generate JWT for authenticated user
  def generate_jwt(user)
    payload = { user_id: user.id, exp: 24.hours.from_now.to_i }
    JWT.encode(payload, Rails.application.credentials.secret_key_base)
  end
end
