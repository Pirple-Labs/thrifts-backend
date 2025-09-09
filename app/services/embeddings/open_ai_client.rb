# app/services/embeddings/open_ai_client.rb
# frozen_string_literal: true
require "net/http"
require "uri"
require "json"
require "digest"

module Embeddings
  class OpenAIClient
    class Error < StandardError; end
    MODEL   = ENV.fetch("EMBEDDING_MODEL", "text-embedding-3-small")
    DIMS    = 1536
    TIMEOUT = (ENV["OPENAI_EMBED_TIMEOUT"] || 60).to_i

    def self.embed(texts)
      texts = Array(texts).map { |t| (t || "").to_s.strip }
      raise Error, "texts must be non-empty Array" if texts.empty?

      # Local/dev fallback to avoid network during backfill
      return texts.map { |t| fake_vector_for(t, DIMS) } if ENV["EMBEDDINGS_FAKE"] == "1"

      uri = URI.parse(ENV.fetch("OPENAI_EMBED_URL", "https://api.openai.com/v1/embeddings"))
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{ENV.fetch('OPENAI_API_KEY')}"
      req["Content-Type"]  = "application/json"
      req.body = { model: MODEL, input: texts, encoding_format: "float" }.to_json

      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                            open_timeout: TIMEOUT, read_timeout: TIMEOUT) { |h| h.request(req) }
      raise Error, "HTTP #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)

      json = JSON.parse(res.body)
      vecs = Array(json["data"]).sort_by { |d| d["index"].to_i }.map { |d| d["embedding"] }
      vecs.each_with_index do |v, i|
        raise Error, "dims[#{i}] got #{v&.length}, expected #{DIMS}" unless v.is_a?(Array) && v.length == DIMS
      end
      vecs
    rescue => e
      raise Error, "embed failed: #{e.message}"
    end

    def self.fake_vector_for(text, dims)
      seed = Digest::SHA256.hexdigest(text)
      rng  = Random.new(seed.to_i(16) % 2_147_483_647)
      arr  = Array.new(dims) { (rng.rand - 0.5) * 0.2 }
      norm = Math.sqrt(arr.sum { |x| x * x })
      norm.zero? ? arr : arr.map { |x| x / norm }
    end
  end
end
