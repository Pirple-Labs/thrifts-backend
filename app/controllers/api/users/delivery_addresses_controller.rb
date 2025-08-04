# app/controllers/api/users/delivery_addresses_controller.rb

module Api
  module Users
    class DeliveryAddressesController < Api::BaseController
      def index
        render json: {
          success: true,
          addresses: current_user.delivery_addresses.order(created_at: :desc)
        }
      end

      def create
        address = current_user.delivery_addresses.new(address_params)
        if address.save
          render json: { success: true, address: address }
        else
          render json: {
            success: false,
            error: address.errors.full_messages.to_sentence
          }, status: :unprocessable_entity
        end
      end

      def destroy
        address = current_user.delivery_addresses.find_by(id: params[:id])
        if address
          address.destroy
          render json: { success: true }
        else
          render json: { success: false, error: "Address not found" }, status: :not_found
        end
      end

      private

      def address_params
        params.require(:delivery_address).permit(:nickname, :phone, :location, :pickup_agent)
      end
    end
  end
end
