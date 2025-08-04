require "net/http"
require "uri"
require "json"

class ModerationService
  SINGLE_ENDPOINT = ENV.fetch("SENTRY_AGENT_URL", "http://127.0.0.1:5000/moderate")
  BATCH_ENDPOINT  = ENV.fetch("SENTRY_AGENT_BATCH_URL", "http://127.0.0.1:5000/moderate/batch")
  BATCH_SIZE      = 30

  def initialize(product_or_products, image_url_or_urls, user_id:)
    @user_id    = user_id

    if product_or_products.is_a?(Array)
      @products   = product_or_products
      @image_urls = image_url_or_urls
      @batch_mode = true
    else
      @product    = product_or_products
      @image_url  = image_url_or_urls
      @batch_mode = false
    end
  end

  def call
    @batch_mode ? moderate_batch : moderate_single
  end

  private

  def moderate_single
    Rails.logger.info "🧪 [ModerationService] Single moderation: #{@image_url}"
    response = post_to_flask(SINGLE_ENDPOINT, { image_url: @image_url })
    parsed   = JSON.parse(response.body, symbolize_names: true)
    log_and_update(@product, parsed.merge(image_url: @image_url))
    parsed
  rescue => e
    handle_single_failure(e)
  end

  def moderate_batch
    all_results = []

    @image_urls.each_slice(BATCH_SIZE).with_index do |slice_urls, idx|
      Rails.logger.info "🧪 [ModerationService] Batch \#{idx+1}: moderating \#{slice_urls.size} images"
      slice_products = @products.select { |p| slice_urls.include?(p.main_image) }

      batch_results =
        begin
          response = post_to_flask(BATCH_ENDPOINT, { image_urls: slice_urls })
          Rails.logger.info "🧪 [ModerationService] Batch \#{idx+1} response: \#{response.code}"
          JSON.parse(response.body, symbolize_names: true)
        rescue => e
          Rails.logger.error "❌ [ModerationService] Batch \#{idx+1} error: \#{e.class} – \#{e.message}"
          slice_urls.map { |url| { image_url: url, category: 'error', confidence: 0.0, reason: e.message } }
        end

      batch_results.each do |res|
        product = slice_products.find { |p| p.main_image == res[:image_url] }
        next unless product
        log_and_update(product, res)
      end

      all_results.concat(batch_results)
    end

    all_results
  end

  def post_to_flask(endpoint, payload)
    uri  = URI.parse(endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 10   # seconds
    http.read_timeout = 300  # seconds

    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = payload.to_json

    Rails.logger.info "🧪 [ModerationService] POST \#{endpoint} payload: \#{payload.inspect}"
    response = http.request(request)
    Rails.logger.info "🧪 [ModerationService] ← \#{response.code}: \#{response.body}"

    unless response.code == "200"
      raise "Flask returned \#{response.code}: \#{response.body}"
    end

    response
  end

  def log_and_update(product, res)
    category   = res[:category]   || "error"
    confidence = res[:confidence] || 0.0
    reason     = res[:reason]     || "Unknown"
    img_url    = res[:image_url]

    product.moderation_events.create!(
      user_id:            @user_id,
      image_url:          img_url,
      predicted_label:    category,
      confidence:         confidence,
      final_label:        category,
      is_manual_override: false,
      notes:              reason
    )

    product.update!(
      moderation_status:     "moderated",
      moderation_label:      category,
      moderation_confidence: confidence
    )
  end

  def handle_single_failure(exception)
    Rails.logger.error "❌ [ModerationService] Single error: \#{exception.class} – \#{exception.message}"
    log_and_update(@product, image_url: @image_url, category: "error", confidence: 0.0, reason: exception.message)
    { category: "error", confidence: 0.0, reason: exception.message }
  end
end
