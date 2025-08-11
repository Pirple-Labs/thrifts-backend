# app/controllers/api/payments/daraja_callbacks_controller.rb
module Api
  module Payments
    class DarajaCallbacksController < ApplicationController
      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate_user!, raise: false
      skip_before_action :authorize_request, raise: false
      skip_before_action :authenticate_api_user!, raise: false
      # POST /api/payments/callback   (and/or /api/payments/daraja/callback)
      def create
        payload = safe_payload
        Rails.logger.info("[Daraja][CB] payload: #{payload}")

        cb = dig_cb(payload)
        return head :ok unless cb

        crid  = cb["CheckoutRequestID"]
        rcode = cb["ResultCode"].to_i
        rdesc = cb["ResultDesc"]

        items   = cb.dig("CallbackMetadata", "Item") || []
        receipt = items.find { |i| i["Name"] == "MpesaReceiptNumber" }&.dig("Value")
        amt     = items.find { |i| i["Name"] == "Amount" }&.dig("Value")
        phone   = items.find { |i| i["Name"] == "PhoneNumber" }&.dig("Value")

        payment = Payment.find_by(mpesa_checkout_request_id: crid)
        unless payment
          Rails.logger.warn("[Daraja][CB] Payment not found for CheckoutRequestID=#{crid}")
          return head :ok
        end

        status =
          case rcode
          when 0     then "success"
          when 1032  then "cancelled"                          # user cancelled
          when 2006  then "timeout"                            # system timeout
          when 1037  then "timeout"                            # DS timeout user cannot be reached
          else             "failed"
          end

        terminal = %w[success failed cancelled timeout].include?(status)

        payment.update!(
          status:               status,
          result_code:          rcode,
          result_desc:          rdesc,
          mpesa_receipt_number: receipt.presence || payment.mpesa_receipt_number,
          amount:               (amt.to_i if amt).presence || payment.amount,
          total_amount:         (amt.to_i if amt).presence || payment.total_amount,
          phone_number_used:    (phone.to_s if phone).presence || payment.phone_number_used,
          completed_at:         (Time.current if terminal),
          raw_callback:         payload
        )

        head :ok
      # app/controllers/api/payments/daraja_callbacks_controller.rb (rescue block)
      rescue => e
        Rails.logger.error("[Daraja][CB][ERROR] #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.first(10).join("\n"))
        head :ok
      end


      private

      # Handles either:
      # {"Body"=>{"stkCallback"=>{...}}} or {"daraja_callback"=>{"Body"=>{"stkCallback"=>{...}}}}
      def dig_cb(payload)
        body = payload["Body"] || payload.dig("daraja_callback", "Body")
        body && body["stkCallback"]
      end

      def safe_payload
        h = params.to_unsafe_h
        return h if h.key?("Body") || h.key?("daraja_callback")
        JSON.parse(request.raw_post)
      rescue
        { "raw" => (request.raw_post.presence || "<empty>") }
      end
    end
  end
end
