# frozen_string_literal: true

class RequestIdMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Set request ID from header or generate new one
    request_id = request.headers['X-Request-Id'] || SecureRandom.uuid
    
    # Set in Current attributes for use throughout request
    Current.request_id = request_id
    
    # Add to response headers
    status, headers, response = @app.call(env)
    headers['X-Request-Id'] = request_id
    
    [status, headers, response]
  end
end

