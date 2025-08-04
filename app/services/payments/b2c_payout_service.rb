# app/services/mpesa/b2c_payout_service.rb
require 'httparty'

module Mpesa
  class B2cPayoutService
    include HTTParty
    base_uri ENV['MPESA_BASE_URL']

    def initialize(phone_number:, amount:, remarks:)
      @phone_number = format_phone(phone_number)
      @amount = amount
      @remarks = remarks
    end

    def call
      self.class.post(
        "/mpesa/b2c/v1/paymentrequest",
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Content-Type" => "application/json"
        },
        body: {
          InitiatorName: ENV["MPESA_INITIATOR_NAME"],
          SecurityCredential: security_credential,
          CommandID: "BusinessPayment",
          Amount: @amount,
          PartyA: ENV["MPESA_SHORTCODE"],
          PartyB: @phone_number,
          Remarks: @remarks,
          QueueTimeOutURL: ENV["MPESA_B2C_TIMEOUT_URL"],
          ResultURL: ENV["MPESA_B2C_RESULT_URL"],
          Occasion: "ThriftsMerchantPayout"
        }.to_json
      ).yield_self { |res| JSON.parse(res.body) }
    end

    private

    def access_token
      response = self.class.basic_auth(
        ENV['MPESA_CONSUMER_KEY'],
        ENV['MPESA_CONSUMER_SECRET']
      ).get("/oauth/v1/generate?grant_type=client_credentials")

      JSON.parse(response.body)["access_token"]
    end

    def format_phone(phone)
      phone.gsub(/^0/, '254') # e.g., 0712... → 254712...
    end

    def security_credential
      # For sandbox use hardcoded test credential
      ENV['MPESA_SECURITY_CREDENTIAL'] || "Safaricom123!"
    end
  end
end
