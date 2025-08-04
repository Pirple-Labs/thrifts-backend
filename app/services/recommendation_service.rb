class RecommendationService
  ENDPOINT = ENV.fetch("RECOMMENDER_AGENT_URL", "http://127.0.0.1:5000/api/recommendations")

  def self.refresh_for(product_id)
    response = HTTParty.post("#{ENDPOINT}/#{product_id}")
    raise "Flask agent error: #{response.code}" unless response.code == 200

    JSON.parse(response.body)
  end
end
