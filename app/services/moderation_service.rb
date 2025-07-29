require "net/http"
require "uri"
require "json"

class ModerationService
  FLASK_ENDPOINT = ENV.fetch("SENTRY_AGENT_URL", "http://127.0.0.1:5000/moderate")

  def initialize(product, image_url, user_id:)
    @product = product
    @image_url = image_url
    @user_id = user_id
  end

  def call
    uri = URI.parse(FLASK_ENDPOINT)
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = { image_url: @image_url }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }

    unless response.code == "200"
      raise "Flask agent failed with status #{response.code}: #{response.body}"
    end

    parsed = JSON.parse(response.body, symbolize_names: true)

    @product.moderation_events.create!(
      user_id: @user_id,
      image_url: @image_url,
      predicted_label: parsed[:category],
      confidence: parsed[:confidence],
      final_label: parsed[:category],
      is_manual_override: false,
      notes: parsed[:reason]
    )

    parsed
  rescue => e
    @product.moderation_events.create!(
      user_id: @user_id,
      image_url: @image_url,
      predicted_label: "error",
      confidence: 0.0,
      final_label: "error",
      is_manual_override: false,
      notes: e.message
    )
    {
      category: "error",
      confidence: 0.0,
      reason: e.message
    }
  end
end
