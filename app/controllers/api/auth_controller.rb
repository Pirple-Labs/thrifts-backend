class Api::AuthController < ApplicationController
    require 'jwt'
  
    def google
      Rails.logger.info "Received Google Auth Request: #{params.inspect}" # Debugging Log
  
      user_info = params.permit(:email, :name, :googleId, :avatar)
  
      user = User.find_or_initialize_by(email: user_info[:email])
  
      if user.new_record?
        user.name = user_info[:name]
        user.google_id = user_info[:googleId]
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
  