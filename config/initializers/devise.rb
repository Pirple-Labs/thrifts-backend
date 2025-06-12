# frozen_string_literal: true

Devise.setup do |config|
  require "dotenv/load"
  config.mailer_sender = 'please-change-me@example.com'
  require 'devise/orm/active_record'

  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 12
  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.expire_all_remember_me_on_sign_out = true
  config.reconfirmable = true
  config.reset_password_within = 6.hours
  config.sign_out_via = :delete

  # ✅ JWT
config.jwt do |jwt|
  secret = Rails.application.credentials[:devise_jwt_secret_key]

  jwt.secret = secret  # <--- you need this line to set the secret
  jwt.dispatch_requests = [
    ['POST', %r{^/api/auth/manual_login$}],
    ['POST', %r{^/api/auth/google_login$}],
    ['POST', %r{^/api/auth/signup$}]
  ]
  jwt.revocation_requests = [['DELETE', %r{^/api/auth/logout$}]]
  jwt.expiration_time = 1.day.to_i
end


  # ✅ Google OAuth
  config.omniauth :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'], scope: 'email,profile'
end
