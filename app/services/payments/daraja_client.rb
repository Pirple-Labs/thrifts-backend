# app/services/payments/daraja_client.rb
require "base64"
require "faraday"
require "json"

module Payments
  class DarajaClient
    OAUTH_PATH = "/oauth/v1/generate?grant_type=client_credentials"
    STK_PATH   = "/mpesa/stkpush/v1/processrequest"

    def initialize(logger: Rails.logger)
        @consumer_key    = ENV.fetch("MPESA_CONSUMER_KEY").to_s.strip
        @consumer_secret = ENV.fetch("MPESA_CONSUMER_SECRET").to_s.strip
        @shortcode       = ENV.fetch("MPESA_SHORTCODE").to_s.strip
        @passkey         = ENV.fetch("MPESA_PASSKEY").to_s.strip
        @callback_url    = ENV.fetch("MPESA_CALLBACK_URL").to_s.strip
        @base_url        = ENV.fetch("MPESA_BASE_URL", "https://sandbox.safaricom.co.ke").to_s.strip.sub(%r{/$}, "")

        @logger          = logger
    end

    # Kick off an STK Push
    def stk_push(amount:, phone:, account_reference: "THRIFTS", txn_desc: "Order Payment")
      ts       = timestamp_ke
      password = Base64.strict_encode64("#{@shortcode}#{@passkey}#{ts}")

      payload = {
        BusinessShortCode: @shortcode,
        Password:          password,
        Timestamp:         ts,
        TransactionType:   "CustomerPayBillOnline",
        Amount:            amount.to_s,
        PartyA:            normalize_msisdn(phone),
        PartyB:            @shortcode,
        PhoneNumber:       normalize_msisdn(phone),
        CallBackURL:       @callback_url,
        AccountReference:  account_reference,
        TransactionDesc:   txn_desc
      }

      token = access_token

      # ---------- DEBUG (safe) ----------
      @logger.info("[Daraja][DEBUG] base_url=#{@base_url}")
      @logger.info("[Daraja][DEBUG] shortcode=#{@shortcode}, phone_norm=#{payload[:PhoneNumber]}, ts=#{ts}")
      @logger.info("[Daraja][DEBUG] passkey_len=#{@passkey.to_s.length}")
      @logger.info("[Daraja][DEBUG] password_b64_prefix=#{password[0,6]}*** len=#{password.length}")
      # ----------------------------------

      @logger.info("[Daraja] STK request payload: #{redact(payload)}")

      res = connection.post("#{@base_url}#{STK_PATH}") do |req|
        req.headers["Authorization"] = "Bearer #{token}"
        req.headers["Content-Type"]  = "application/json"
        req.headers["User-Agent"]    = "Thrifts-Rails/1.0"
        req.body = JSON.dump(payload)
      end

      body = parse_json(res.body)
      @logger.info("[Daraja] STK response (#{res.status}): #{body}")

      if res.status == 200 && body["ResponseCode"] == "0"
        body
      else
        raise StandardError, "Daraja STK error: HTTP #{res.status} #{body}"
      end
    end

    private

    def access_token
      res = connection.get("#{@base_url}#{OAUTH_PATH}") do |req|
        req.headers["Authorization"] = "Basic #{basic_auth_header}"
        req.headers["User-Agent"]    = "Thrifts-Rails/1.0"
      end
      body = parse_json(res.body)
      @logger.info("[Daraja] OAuth response (#{res.status}): #{body}")
      raise StandardError, "OAuth failure: HTTP #{res.status} #{body}" unless res.status == 200 && body["access_token"]
      body["access_token"]
    end

    def basic_auth_header
      Base64.strict_encode64("#{@consumer_key}:#{@consumer_secret}")
    end

    def connection
      @connection ||= Faraday.new do |f|
        f.request :url_encoded
        f.options.timeout      = 20
        f.options.open_timeout = 10
        f.adapter Faraday.default_adapter
      end
    end

    def timestamp_ke
      Time.now.in_time_zone("Africa/Nairobi").strftime("%Y%m%d%H%M%S")
    end

    def normalize_msisdn(msisdn)
      s = msisdn.to_s.strip.gsub(/^\+/, "")
      s = "254#{s[1..-1]}" if s.start_with?("07") && s.length == 10
      s
    end

    def parse_json(str)
      JSON.parse(str)
    rescue JSON::ParserError
      { "raw" => str }
    end

    def redact(payload)
      hidden = payload.dup
      hidden[:Password] = "***"
      hidden
    end
  end
end
