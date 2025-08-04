module Api
  module Payments
    class CallbacksController < ActionController::API
      def stk_callback
        body = JSON.parse(request.raw_post)
        callback = body.dig("Body", "stkCallback")

        checkout_request_id = callback["CheckoutRequestID"]
        result_code = callback["ResultCode"]
        result_desc = callback["ResultDesc"]

        payment = Payment.find_by(mpesa_checkout_request_id: checkout_request_id)

        if payment.present?
          if result_code == 0
            amount = extract_metadata(callback, "Amount")
            receipt = extract_metadata(callback, "MpesaReceiptNumber")

            payment.update!(
              status: "completed",
              mpesa_receipt_number: receipt,
              total_amount: amount,
              completed_at: Time.current
            )

            # ✅ Generate merchant payments for this payment
            ::Payments::MerchantPaymentGenerator.call(payment)
          else
            payment.update!(status: "failed")
          end
        end

        render json: { message: "STK callback received" }, status: :ok
      rescue => e
        Rails.logger.error("[M-PESA CALLBACK ERROR] #{e.message}")
        render json: { error: "Invalid callback payload" }, status: :bad_request
      end

      private

      def extract_metadata(callback, key)
        callback.dig("CallbackMetadata", "Item")&.find { |i| i["Name"] == key }&.dig("Value")
      end
    end
  end
end
