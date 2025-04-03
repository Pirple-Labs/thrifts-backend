Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:5173'  # Specify your frontend URL (no wildcards)

    resource '*',
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options],
      expose: ['Authorization'],  # Allow frontend to access the 'Authorization' header
      credentials: true  # Allow credentials (cookies, etc.) to be included in the request
  end
end
