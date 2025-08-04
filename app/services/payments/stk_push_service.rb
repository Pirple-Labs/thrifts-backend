# app/services/mpesa/stk_push_service.rb
require 'httparty'
require 'base64'

module Mpesa
  class StkPushService
    include HTTParty
    base_uri ENV['MPESA_BASE_URL']

    def initialize(phone_number:, amount:, account_reference:, transaction_desc:)
      @phone_number = format_phone(phone_number)
      @amount = amount
      @account_reference = account_reference
      @transaction_desc = transaction_desc
    end

    def call
      response = self.class.post(
        "/mpesa/stkpush/v1/processrequest",
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Content-Type" => "application/json"
        },
        body: {
          BusinessShortCode: shortcode,
          Password: encoded_password,
          Timestamp: timestamp,
          TransactionType: "CustomerPayBillOnline",
          Amount: @amount,
          PartyA: @phone_number,
          PartyB: shortcode,
          PhoneNumber: @phone_number,
          CallBackURL: ENV['MPESA_CALLBACK_URL'],
          AccountReference: @account_reference,
          TransactionDesc: @transaction_desc
        }.to_json
      )

      JSON.parse(response.body)
    end

    private

    def access_token
      response = self.class.basic_auth(
        ENV['MPESA_CONSUMER_KEY'],
        ENV['MPESA_CONSUMER_SECRET']
      ).get("/oauth/v1/generate?grant_type=client_credentials")

      JSON.parse(response.body)["access_token"]
    end

    def shortcode
      ENV['MPESA_SHORTCODE']
    end

    def timestamp
      @timestamp ||= Time.now.strftime('%Y%m%d%H%M%S')
    end

    def encoded_password
      raw = "#{shortcode}#{ENV['MPESA_PASSKEY']}#{timestamp}"
      Base64.strict_encode64(raw)
    end

    def format_phone(phone)
      phone.gsub(/^0/, '254') # e.g. 0712... → 254712...
    end
  end
end
