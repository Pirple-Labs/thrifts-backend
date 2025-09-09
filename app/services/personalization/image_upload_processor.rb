# frozen_string_literal: true
require "tempfile"
require "digest"

module Personalization
  class ImageUploadProcessor
    class Error < StandardError; end

    # Configuration
    MAX_FILE_SIZE = (ENV["MAX_IMAGE_UPLOAD_SIZE"] || 10 * 1024 * 1024).to_i # 10MB
    ALLOWED_TYPES = %w[image/jpeg image/jpg image/png image/gif image/webp].freeze
    TEMP_DIR = Rails.root.join("tmp", "image_uploads")

    def self.process_uploaded_image(image_file, user_id:, region:, similarity_threshold: 0.7)
      # Validate file
      validate_image_file(image_file)
      
      # Create temp directory if it doesn't exist
      FileUtils.mkdir_p(TEMP_DIR)
      
      # Generate unique filename
      file_extension = File.extname(image_file.original_filename)
      temp_filename = "upload_#{user_id}_#{SecureRandom.hex(8)}#{file_extension}"
      temp_path = TEMP_DIR.join(temp_filename)
      
      begin
        # Save uploaded file temporarily
        File.open(temp_path, "wb") do |f|
          f.write(image_file.read)
        end
        
        # Generate embedding from uploaded file
        embedding = generate_embedding_from_file(temp_path)
        
        # Perform similarity search
        similar_products = find_similar_products(
          embedding: embedding,
          region: region,
          similarity_threshold: similarity_threshold,
          limit: 50
        )
        
        # Clean up temp file
        File.delete(temp_path) if File.exist?(temp_path)
        
        similar_products
        
      rescue => e
        # Clean up temp file on error
        File.delete(temp_path) if File.exist?(temp_path)
        raise Error, "Image processing failed: #{e.message}"
      end
    end

    private

    def self.validate_image_file(image_file)
      # Check file size
      if image_file.size > MAX_FILE_SIZE
        raise Error, "File too large. Maximum size is #{MAX_FILE_SIZE / 1024 / 1024}MB"
      end
      
      # Check content type
      unless ALLOWED_TYPES.include?(image_file.content_type)
        raise Error, "Invalid file type. Allowed types: #{ALLOWED_TYPES.join(', ')}"
      end
      
      # Check file extension
      allowed_extensions = %w[.jpg .jpeg .png .gif .webp]
      file_extension = File.extname(image_file.original_filename).downcase
      unless allowed_extensions.include?(file_extension)
        raise Error, "Invalid file extension. Allowed extensions: #{allowed_extensions.join(', ')}"
      end
    end

    def self.generate_embedding_from_file(file_path)
      # For now, use a placeholder approach
      # In production, this would:
      # 1. Load the image file
      # 2. Preprocess it (resize, normalize, etc.)
      # 3. Generate embedding using vision model
      
      if ENV["VISION_MODEL_ENABLED"] == "true"
        # Call actual vision model service
        call_vision_model_with_file(file_path)
      else
        # Fallback: generate embedding based on file hash
        file_hash = Digest::SHA256.file(file_path).hexdigest
        generate_hash_based_embedding(file_hash)
      end
    end

    def self.call_vision_model_with_file(file_path)
      # Call your existing vision service with file data
      vision_service_url = ENV.fetch("VISION_SERVICE_URL", "http://127.0.0.1:8001/embed")
      
      uri = URI.parse(vision_service_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 30
      
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/octet-stream"
      
      # Read file and send as binary data
      request.body = File.read(file_path)
      
      response = http.request(request)
      
      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "Vision model failed: #{response.code} - #{response.body}"
      end
      
      result = JSON.parse(response.body)
      embedding = result["embedding"]
      
      Rails.logger.info "Vision service file processing: dim=#{result['dimension']}, time=#{result['processing_time_ms']}ms"
      
      embedding
    rescue => e
      Rails.logger.error "Vision model call failed: #{e.message}"
      # Fallback to hash-based embedding
      file_hash = Digest::SHA256.file(file_path).hexdigest
      generate_hash_based_embedding(file_hash)
    end

    def self.generate_hash_based_embedding(file_hash)
      # Generate a deterministic embedding based on file hash
      # This is a placeholder for demo purposes
      # In production, this would be replaced with actual vision model
      
      # Use the hash to generate a pseudo-random but deterministic vector
      random = Random.new(file_hash.to_i(16))
      embedding = Array.new(512) { random.rand(-1.0..1.0) }
      
      # Normalize the vector
      magnitude = Math.sqrt(embedding.map { |x| x**2 }.sum)
      embedding.map { |x| x / magnitude }
    end

    def self.find_similar_products(embedding:, region:, similarity_threshold:, limit:)
      # Use ProductEmbedding model to find similar products
      similar_products = ProductEmbedding.find_similar_products(
        embedding,
        limit: limit * 2,
        similarity_threshold: similarity_threshold,
        region: region
      )
      
      # Convert to expected format
      similar_products.first(limit).map do |result|
        {
          id: result[:id],
          score: result[:similarity_score],
          similarity_score: result[:similarity_score],
          role: "image_search",
          matched_phrase: "image_similarity"
        }
      end
    end
  end
end
