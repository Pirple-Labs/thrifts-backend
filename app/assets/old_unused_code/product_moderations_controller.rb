# app/controllers/api/moderations/product_moderations_controller.rb

module Api
  module Moderations
    class ProductModerationsController < Api::BaseController
      before_action :authenticate_user!
      before_action :set_product

      def create
        image_url = @product.main_image

        if image_url.blank?
          return render json: { error: "No image found for moderation." }, status: :unprocessable_entity
        end

        begin
          # Send image to Flask moderation agent
          response = ModerationService.moderate(image_url)

          # Save moderation event
          ModerationEvent.create!(
            product_id:       @product.id,
            user_id:          current_user.id,
            image_url:        image_url,
            predicted_label:  response[:category],
            confidence:       response[:confidence],
            final_label:      response[:category],
            is_manual_override: false,
            notes:            response[:reason]
          )

          # Update product with moderation result
          @product.update!(
            moderation_status:     "moderated",
            moderation_label:      response[:category],
            moderation_confidence: response[:confidence]
          )

          render json: { status: "success", result: response }, status: :ok
        rescue => e
          render json: { error: e.message }, status: :bad_gateway
        end
      end

      private

      def set_product
        @product = Product.find(params[:id])
      end
    end
  end
end
