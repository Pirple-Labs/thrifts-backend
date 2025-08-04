module Api
  module Moderations
    class BatchModerationsController < Api::BaseController
      skip_before_action :authenticate_user!

      def create
        # 🔧 LIMIT to 20 products with valid images
        products = Product.where.not(main_image: [nil, ""]).limit(20).to_a

        return render json: { error: "No products with images to moderate." }, status: :unprocessable_entity if products.empty?

        image_urls = products.map(&:main_image)

        flask_response = post_to_flask(
          ENV.fetch("SENTRY_AGENT_BATCH_URL", "http://127.0.0.1:5000/moderate/batch"),
          { image_urls: image_urls }
        )

        results = JSON.parse(flask_response.body)
        breakdown = Hash.new(0)

        results.each do |res|
          product = products.find { |p| p.main_image == res["image_url"] }
          next unless product

          product.update!(
            moderation_label: res["category"],
            moderation_confidence: res["confidence"],
            moderation_reason: res["reason"]
          )

          breakdown[res["category"] || "unknown"] += 1
        end

        render json: {
          status: "moderated",
          moderated_count: results.size,
          breakdown: breakdown
        }, status: :ok

      rescue => e
        render json: { error: "Batch moderation failed", detail: e.message }, status: :bad_gateway
      end

      private

     def post_to_flask(endpoint, payload)
        uri = URI.parse(endpoint)
        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        request.body = payload.to_json
        http.request(request)
    end

    end
  end
end
