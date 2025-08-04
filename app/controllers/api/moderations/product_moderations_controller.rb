module Api
  module Moderations
    class ProductModerationsController < Api::BaseController
      skip_before_action :authenticate_user!  # ← ✅ Disable sign-in requirement
      before_action :set_product

      def create
        if @product.main_image.blank?
          return render json: { error: "No image to moderate." }, status: :unprocessable_entity
        end

        flask_response = post_to_flask(
          ENV.fetch("SENTRY_AGENT_URL", "http://127.0.0.1:5000/moderate"),
          { image_url: @product.main_image }
        )

        result = JSON.parse(flask_response.body)

        @product.update!(
          moderation_label: result["category"],
          moderation_confidence: result["confidence"],
          moderation_reason: result["reason"]
        )

        render json: { status: "updated", moderation: result }, status: :ok

      rescue => e
        Rails.logger.error "❌ Moderation failed: #{e.class} – #{e.message}"
        render json: { error: "Moderation failed", detail: e.message }, status: :bad_gateway
      end

      private

      def set_product
        @product = Product.find(params[:id])
      end

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
