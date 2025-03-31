# frozen_string_literal: true

Devise.setup do |config|
  # Mailer Configuration
  config.mailer_sender = 'please-change-me@example.com'

  # ORM Configuration
  require 'devise/orm/active_record'

  # Authentication Keys
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]

  # Session Storage
  config.skip_session_storage = [:http_auth]

  # Password Security
  config.stretches = Rails.env.test? ? 1 : 12
  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/

  # Rememberable Configuration
  config.expire_all_remember_me_on_sign_out = true

  # Confirmable
  config.reconfirmable = true

  # Recoverable
  config.reset_password_within = 6.hours

  # Sign Out
  config.sign_out_via = :delete

  # === JWT Authentication ===
  config.jwt do |jwt|
    jwt.secret = Rails.application.credentials.devise_jwt_secret_key! # Securely store the secret
    jwt.dispatch_requests = [
      ['POST', %r{^/login$}],
      ['POST', %r{^/signup$}]
    ]
    jwt.revocation_requests = [['DELETE', %r{^/logout$}]]
    jwt.expiration_time = 1.day.to_i # Token expires in 24 hours
  end
end
