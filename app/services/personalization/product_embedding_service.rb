# frozen_string_literal: true
require "net/http"
require "uri"

module Personalization
  class ProductEmbeddingService
    class Error < StandardError; end

    # Configuration
    VISION_SERVICE_URL = ENV.fetch("VISION_SERVICE_URL", "http://127.0.0.1:8001")
    BATCH_SIZE = 10
    MAX_RETRIES = 3

    def self.generate_product_embeddings(embedding_type: 'image', limit: nil, force_regenerate: false)
      # Get products that need embeddings
      products = get_products_for_embedding(embedding_type, limit, force_regenerate)
      
      Rails.logger.info "Generating #{embedding_type} embeddings for #{products.count} products"
      
      results = {
        processed: 0,
        successful: 0,
        failed: 0,
        errors: []
      }
      
      products.find_in_batches(batch_size: BATCH_SIZE) do |batch|
        batch_results = process_batch(batch, embedding_type)
        
        results[:processed] += batch_results[:processed]
        results[:successful] += batch_results[:successful]
        results[:failed] += batch_results[:failed]
        results[:errors].concat(batch_results[:errors])
        
        # Log progress
        Rails.logger.info "Processed batch: #{batch_results[:processed]} products, #{batch_results[:successful]} successful, #{batch_results[:failed]} failed"
      end
      
      Rails.logger.info "Embedding generation complete: #{results}"
      results
    end

    def self.generate_single_product_embedding(product_id, embedding_type: 'image')
      product = Product.find(product_id)
      
      unless product.image_url.present?
        raise Error, "Product #{product_id} has no image URL"
      end
      
      # Generate embedding
      embedding = generate_embedding_from_url(product.image_url)
      
      # Store embedding
      ProductEmbedding.store_embedding(
        product_id: product_id,
        embedding_vector: embedding,
        embedding_type: embedding_type,
        model_version: 'v1.0',
        metadata: {
          image_url: product.image_url,
          generated_at: Time.current.iso8601
        }
      )
      
      Rails.logger.info "Generated #{embedding_type} embedding for product #{product_id}"
      embedding
      
    rescue => e
      Rails.logger.error "Failed to generate embedding for product #{product_id}: #{e.message}"
      raise Error, "Embedding generation failed: #{e.message}"
    end

    private

    def self.get_products_for_embedding(embedding_type, limit, force_regenerate)
      base_query = Product.joins(:shop)
                         .where("products.stock > 0")
                         .where("products.moderation_status = ?", "approved")
                         .where("products.image_url IS NOT NULL")
                         .where("products.image_url != ''")
      
      if force_regenerate
        # Regenerate all embeddings
        base_query
      else
        # Only products without embeddings
        base_query.left_joins(:product_embeddings)
                 .where(product_embeddings: { embedding_type: embedding_type, id: nil })
      end
      
      base_query.limit(limit) if limit
    end

    def self.process_batch(products, embedding_type)
      results = {
        processed: 0,
        successful: 0,
        failed: 0,
        errors: []
      }
      
      products.each do |product|
        results[:processed] += 1
        
        begin
          generate_single_product_embedding(product.id, embedding_type: embedding_type)
          results[:successful] += 1
        rescue => e
          results[:failed] += 1
          results[:errors] << {
            product_id: product.id,
            error: e.message
          }
        end
      end
      
      results
    end

    def self.generate_embedding_from_url(image_url)
      # Fetch image from URL
      image_data = fetch_image_from_url(image_url)
      
      # Call vision service
      call_vision_service(image_data)
    end

    def self.fetch_image_from_url(image_url)
      uri = URI.parse(image_url)
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 30
      
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Thrifts-ProductEmbedding/1.0"
      
      response = http.request(request)
      
      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "Failed to fetch image: HTTP #{response.code}"
      end
      
      # Check content type
      content_type = response["content-type"]&.downcase
      unless content_type&.start_with?("image/")
        raise Error, "Invalid content type: #{content_type}"
      end
      
      response.body
    rescue => e
      raise Error, "Image fetch failed: #{e.message}"
    end

    def self.call_vision_service(image_data)
      uri = URI.parse("#{VISION_SERVICE_URL}/embed")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 30
      
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/octet-stream"
      request.body = image_data
      
      response = http.request(request)
      
      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "Vision service failed: HTTP #{response.code} - #{response.body}"
      end
      
      result = JSON.parse(response.body)
      embedding = result["embedding"]
      
      Rails.logger.debug "Vision service response: dim=#{result['dimension']}, time=#{result['processing_time_ms']}ms"
      
      embedding
    rescue => e
      raise Error, "Vision service call failed: #{e.message}"
    end
  end
end
