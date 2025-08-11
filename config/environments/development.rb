# config/environments/development.rb
require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Reload code on every request (good for development)
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true

  # Allow ngrok (public tunnel) to hit our dev server for Daraja callbacks
  # Matches any subdomain like https://<random>.ngrok-free.app
  config.hosts << /[a-z0-9-]+\.ngrok-free\.app/

  # Server timing headers
  config.server_timing = true

  # Caching setup
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.cache_store = :memory_store
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  end

  # File storage
  config.active_storage.service = :local

  # Mailer setup (for Devise email confirmations)
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }

  config.action_mailer.smtp_settings = {
    address:              "smtp.gmail.com",
    port:                 587,
    domain:               "localhost",
    user_name:            ENV["SMTP_USERNAME"], # ensure this is set in .env if you use email locally
    password:             ENV["SMTP_PASSWORD"],
    authentication:       "plain",
    enable_starttls_auto: true
  }

  # Deprecation & migration notices
  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load

  # Database query logging
  config.active_record.verbose_query_logs = true
  config.active_record.query_log_tags_enabled = true

  # Background jobs
  config.active_job.verbose_enqueue_logs = true

  # Annotate views with filenames
  config.action_view.annotate_rendered_view_with_filenames = true

  # Raise if a controller callback references a missing action
  config.action_controller.raise_on_missing_callback_actions = true

  # Cookies policy for dev (adjust if needed)
  config.action_dispatch.cookies_same_site_protection = :none
end
