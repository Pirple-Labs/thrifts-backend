# frozen_string_literal: true
require "net/http"
require "uri"
require "redis"

module Personalization
  class ImageEmbedder
    class Error < StandardError; end

    # Configuration
    VISION_INDEX_VERSION = ENV.fetch("VISION_INDEX_VERSION", "clip_v1")
    EMBEDDING_CACHE_TTL = 7.days.to_i
    FETCH_TIMEOUT = (ENV["IMAGE_FETCH_TIMEOUT"] || 800).to_i # ms
    MAX_IMAGE_SIZE = (ENV["MAX_IMAGE_SIZE"] || 5 * 1024 * 1024).to_i # 5MB
    
    def self.allowed_host?(url)
      host = URI.parse(url).host rescue nil
      return false unless host
      allow = ENV.fetch("CLOUDINARY_HOST_ALLOWLIST", "res.cloudinary.com").split(",").map(&:strip)
      allow.any? { |h| host.end_with?(h) }
    end

    # Returns embedding Array (float[]) or raises Error
    def self.embed_image(url)
      raise Error, "invalid host" unless allowed_host?(url)
      
      # Check cache first
      cache_key = build_cache_key(url)
      cached_embedding = get_cached_embedding(cache_key)
      return cached_embedding if cached_embedding
      
      # Fetch and embed image
      embedding = fetch_and_embed_image(url)
      
      # Cache the result
      cache_embedding(cache_key, embedding)
      
      embedding
    rescue => e
      Rails.logger.error "Image embedding failed for #{url}: #{e.message}"
      raise Error, "embedding failed: #{e.message}"
    end

    private

    def self.build_cache_key(url)
      # Parse Cloudinary URL and normalize transform
      parsed = parse_cloudinary_url(url)
      return nil unless parsed
      
      # Create deterministic cache key
      normalized_transform = normalize_transform(parsed[:transform])
      "img_emb:#{parsed[:public_id]}|#{normalized_transform}|#{VISION_INDEX_VERSION}"
    end

    def self.parse_cloudinary_url(url)
      # Parse Cloudinary URL structure
      # Example: https://res.cloudinary.com/demo/image/upload/w_512,h_512,c_fit,f_auto,q_auto/sample.jpg
      uri = URI.parse(url)
      return nil unless uri.host&.end_with?("cloudinary.com")
      
      path_parts = uri.path.split("/")
      upload_index = path_parts.index("upload")
      return nil unless upload_index && upload_index < path_parts.length - 1
      
      transform_part = path_parts[upload_index + 1]
      public_id = path_parts[upload_index + 2..-1].join("/")
      
      {
        public_id: public_id,
        transform: transform_part,
        full_url: url
      }
    rescue => e
      Rails.logger.error "Failed to parse Cloudinary URL #{url}: #{e.message}"
      nil
    end

    def self.normalize_transform(transform)
      # Normalize Cloudinary transform parameters for consistent caching
      # Default transform: w_512,h_512,c_fit,f_auto,q_auto
      return "w_512,h_512,c_fit,f_auto,q_auto" if transform.blank?
      
      # Parse and normalize common parameters
      params = transform.split(",").map(&:strip).sort
      
      # Ensure consistent ordering and default values
      normalized = []
      normalized << "w_512" unless params.any? { |p| p.start_with?("w_") }
      normalized << "h_512" unless params.any? { |p| p.start_with?("h_") }
      normalized << "c_fit" unless params.any? { |p| p.start_with?("c_") }
      normalized << "f_auto" unless params.any? { |p| p.start_with?("f_") }
      normalized << "q_auto" unless params.any? { |p| p.start_with?("q_") }
      
      # Add any custom parameters
      params.each do |param|
        normalized << param unless normalized.any? { |n| n.start_with?(param.split("_").first + "_") }
      end
      
      normalized.sort.join(",")
    end

    def self.get_cached_embedding(cache_key)
      return nil unless cache_key
      
      # Try Redis cache first (fast)
      cached = Redis.current.get(cache_key)
      if cached
        begin
          return JSON.parse(cached)
        rescue => e
          Rails.logger.error "Failed to parse cached embedding: #{e.message}"
        end
      end
      
      # Try persistent cache (database)
      begin
        persistent_embedding = SearchImageCache.find_embedding(cache_key)
        if persistent_embedding
          # Warm Redis cache
          Redis.current.setex(cache_key, EMBEDDING_CACHE_TTL, persistent_embedding.to_json)
          return persistent_embedding
        end
      rescue => e
        Rails.logger.error "Failed to query persistent cache: #{e.message}"
      end
      
      nil
    end

    def self.cache_embedding(cache_key, embedding)
      return unless cache_key && embedding
      
      # Store in Redis (fast access)
      begin
        Redis.current.setex(cache_key, EMBEDDING_CACHE_TTL, embedding.to_json)
      rescue => e
        Rails.logger.error "Failed to cache embedding in Redis: #{e.message}"
      end
      
      # Store in persistent cache (database) for long-term storage
      begin
        parsed = parse_cache_key(cache_key)
        if parsed
          SearchImageCache.store_embedding(
            cache_key: cache_key,
            public_id: parsed[:public_id],
            transform_params: parsed[:transform],
            version: parsed[:version],
            embedding: embedding
          )
        end
      rescue => e
        Rails.logger.warn "Failed to store embedding in persistent cache: #{e.message}"
      end
    end

    def self.parse_cache_key(cache_key)
      # Parse: "img_emb:public_id|transform|version"
      match = cache_key.match(/^img_emb:(.+)\|(.+)\|(.+)$/)
      return nil unless match
      
      {
        public_id: match[1],
        transform: match[2],
        version: match[3]
      }
    end

    def self.fetch_and_embed_image(url)
      # Fetch image with timeout and size limits
      image_data = fetch_image(url)
      
      # Generate embedding using vision model
      generate_embedding(image_data)
    end

    def self.fetch_image(url)
      uri = URI.parse(url)
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = FETCH_TIMEOUT / 1000.0
      http.read_timeout = FETCH_TIMEOUT / 1000.0
      
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Thrifts-ImageEmbedder/1.0"
      
      response = http.request(request)
      
      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "HTTP #{response.code}: #{response.body}"
      end
      
      # Check content type
      content_type = response["content-type"]&.downcase
      unless content_type&.start_with?("image/")
        raise Error, "Invalid content type: #{content_type}"
      end
      
      # Check size limit
      if response.body.bytesize > MAX_IMAGE_SIZE
        raise Error, "Image too large: #{response.body.bytesize} bytes (max: #{MAX_IMAGE_SIZE})"
      end
      
      response.body
    rescue => e
      raise Error, "fetch failed: #{e.message}"
    end

    def self.generate_embedding(image_data)
      # For now, use a placeholder vision model service
      # In production, this would call your actual CLIP-like model
      if ENV["VISION_MODEL_ENABLED"] == "true"
        call_vision_model(image_data)
      else
        # Fallback to OpenAI embedding on image hash (temporary)
        image_hash = Digest::SHA256.hexdigest(image_data)
        Embeddings::OpenAIClient.embed([image_hash]).first
      end
    end

    def self.call_vision_model(image_data)
      # Call your existing vision service
      vision_service_url = ENV.fetch("VISION_SERVICE_URL", "http://127.0.0.1:8001/embed")
      
      uri = URI.parse(vision_service_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 30
      
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/octet-stream"
      request.body = image_data
      
      response = http.request(request)
      
      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "Vision model failed: #{response.code} - #{response.body}"
      end
      
      result = JSON.parse(response.body)
      embedding = result["embedding"]
      
      Rails.logger.info "Vision service response: dim=#{result['dimension']}, time=#{result['processing_time_ms']}ms"
      
      embedding
    rescue => e
      Rails.logger.error "Vision model call failed: #{e.message}"
      # Fallback to hash-based embedding
      image_hash = Digest::SHA256.hexdigest(image_data)
      generate_hash_based_embedding(image_hash)
    end

    def self.generate_hash_based_embedding(image_hash)
      # Generate a deterministic embedding based on image hash as fallback
      random = Random.new(image_hash.to_i(16))
      embedding = Array.new(512) { random.rand(-1.0..1.0) }
      
      # Normalize the vector
      magnitude = Math.sqrt(embedding.map { |x| x**2 }.sum)
      embedding.map { |x| x / magnitude }
    end
  end
end


