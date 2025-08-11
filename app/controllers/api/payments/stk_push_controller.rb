# app/controllers/api/payments/stk_push_controller.rb
module Api
  module Payments
    class StkPushController < Api::BaseController
      # POST /api/payments/stk_push
      def create
        # Accept both the new keys and your legacy keys from the frontend
        amount_param = params[:amount] || params[:total_amount]
        phone_param  = params[:phone]  || params[:phone_number_used]

        amount = amount_param.to_i
        return render json: { ok: false, error: "Amount must be >= 1" }, status: :unprocessable_entity if amount < 1

        phone = normalize_msisdn(phone_param.to_s)
        return render json: { ok: false, error: "Invalid phone" }, status: :unprocessable_entity unless phone.match?(/^254(7|1)\d{8}$/)

        checkout_key      = params[:checkout_key].presence || SecureRandom.uuid
        account_reference = params[:account_reference].presence || "THRIFTS"
        txn_desc          = params[:txn_desc].presence || "Order Payment"

        client = ::Payments::DarajaClient.new
        rsp = client.stk_push(
          amount: amount,
          phone:  phone,
          account_reference: account_reference,
          txn_desc: txn_desc
        )
        # Expect rsp["ResponseCode"] == "0" here (client raises otherwise)

        payment = ::Payment.create!(
          user: current_user,
          gateway: "mpesa",
          amount: amount,                                 # integer (whole KES)
          total_amount: amount,                           # keep your decimal field in sync (optional)
          status: "pending",
          phone_number_used: phone,
          checkout_key: checkout_key,
          mpesa_checkout_request_id:  rsp["CheckoutRequestID"],
          mpesa_merchant_request_id: rsp["MerchantRequestID"]
        )

        render json: {
          id: payment.id,
          status: payment.status,
          amount: payment.amount,
          msisdn: payment.phone_number_used,
          CheckoutRequestID: payment.mpesa_checkout_request_id,
          MerchantRequestID: payment.mpesa_merchant_request_id
        }, status: :ok
      # app/controllers/api/payments/stk_push_controller.rb (rescue block)
      rescue => e
        Rails.logger.error("[Daraja][INIT][ERROR] #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.first(10).join("\n"))
        render json: { ok: false, error: e.message }, status: :unprocessable_entity
      end


      private

      # 07xxxxxxxx / 01xxxxxxxx / +2547/1… → 2547/1…
      def normalize_msisdn(input)
        raw = input.to_s.strip
        digits = raw.gsub(/[^\d]/, "")
        return "" if digits.blank?

        return "254#{digits[1..-1]}" if (%w[07 01].include?(digits[0,2]) && digits.length == 10)
        return digits if digits.start_with?("254") && digits.length == 12
        return digits[1..-1] if raw.start_with?("+") && digits.start_with?("254") && digits.length == 12

        digits
      end
    end
  end
end
