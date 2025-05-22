require_relative "boot"

require "rails/all"
require "dotenv/load"
require "dotenv/rails"   # Updated to replace deprecated Dotenv::Railtie.load

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ThriftsBackend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    config.action_dispatch.allow_browser = true # allow all browsers

    config.api_only = true

    config.action_dispatch.default_headers['Referrer-Policy'] = 'no-referrer-when-downgrade'
    config.middleware.use ActionDispatch::Session::CookieStore, key: '_your_app_session'

    # Add other lib folders to ignore from autoload/reload if needed
    config.autoload_lib(ignore: %w[assets tasks])
  end
end
