require_relative "boot"

require "rails/all"
require "dotenv/load"
Dotenv::Railtie.load

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ThriftsBackend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0
    config.action_dispatch.allow_browser = true
     # Add this line to allow all browsers
     
     config.api_only = true
     config.action_dispatch.default_headers['Referrer-Policy'] = 'no-referrer-when-downgrade'
     config.middleware.use ActionDispatch::Session::CookieStore, key: '_your_app_session'
    
    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])
  end
end
