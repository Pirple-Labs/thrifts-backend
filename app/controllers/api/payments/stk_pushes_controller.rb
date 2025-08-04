module Api
  module Payments
    class StkPushesController < BaseController
      def create
        phone = params[:phone] || current_user.phone
        amount = params[:amount]
        order_ids = params[:order_ids] || [params[:order_id]]

        response = ::Mpesa::StkPushService.new(
          phone_number: phone,
          amount: amount,
          account_reference: "THRIFTS-CHECKOUT-#{SecureRandom.hex(4)}",
          transaction_desc: "Payment for Orders #{order_ids.join(', ')}"
        ).call

        if response["ResponseCode"] == "0"
          payment = Payment.create!(
            user: current_user,
            total_amount: amount,
            status: "pending",
            mpesa_checkout_request_id: response["CheckoutRequestID"],
            phone_number_used: phone
          )

          # 💳 Link payment to each order
          Order.where(id: order_ids, user_id: current_user.id).update_all(payment_id: payment.id)

          render json: { success: true, payment_id: payment.id }, status: :ok
        else
          render json: {
            success: false,
            error: response["errorMessage"] || "STK Push failed"
          }, status: :unprocessable_entity
        end
      end
    end
  end
end
