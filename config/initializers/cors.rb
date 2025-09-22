Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allow common frontend development ports
    origins 'http://localhost:3000',  # Next.js default
           'http://localhost:3001',  # Alternative port
           'http://localhost:5173',  # Vite default
           'http://localhost:8080',  # Vue CLI default
           'http://localhost:4200',  # Angular default
           'http://localhost:3000',  # React default
           'http://127.0.0.1:3000',  # Alternative localhost
           'http://127.0.0.1:3001',
           'http://127.0.0.1:5173',
           'http://127.0.0.1:8080',
           'http://127.0.0.1:4200'

    resource '*',
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options, :head],
      expose: ['Authorization'],  # Allow frontend to access the 'Authorization' header
      credentials: true  # Allow credentials (cookies, etc.) to be included in the request
  end
end
