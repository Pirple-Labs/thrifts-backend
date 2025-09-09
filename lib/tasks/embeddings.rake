namespace :embeddings do
  desc "Generate image embeddings for all products"
  task generate_image_embeddings: :environment do
    puts "Starting image embedding generation..."
    
    limit = ENV['LIMIT']&.to_i
    force_regenerate = ENV['FORCE_REGENERATE'] == 'true'
    
    if force_regenerate
      puts "⚠️  FORCE_REGENERATE=true - will regenerate all existing embeddings"
    end
    
    if limit
      puts "Processing #{limit} products"
    else
      puts "Processing all products with images"
    end
    
    start_time = Time.current
    
    results = Personalization::ProductEmbeddingService.generate_product_embeddings(
      embedding_type: 'image',
      limit: limit,
      force_regenerate: force_regenerate
    )
    
    duration = Time.current - start_time
    
    puts "\n" + "="*50
    puts "EMBEDDING GENERATION COMPLETE"
    puts "="*50
    puts "Duration: #{duration.round(2)} seconds"
    puts "Processed: #{results[:processed]} products"
    puts "Successful: #{results[:successful]} embeddings"
    puts "Failed: #{results[:failed]} embeddings"
    
    if results[:errors].any?
      puts "\nErrors:"
      results[:errors].each do |error|
        puts "  Product #{error[:product_id]}: #{error[:error]}"
      end
    end
    
    success_rate = results[:processed] > 0 ? (results[:successful].to_f / results[:processed] * 100).round(2) : 0
    puts "Success rate: #{success_rate}%"
  end

  desc "Generate embedding for a single product"
  task :generate_single, [:product_id] => :environment do |t, args|
    product_id = args[:product_id]
    
    unless product_id
      puts "Usage: rake embeddings:generate_single[123]"
      exit 1
    end
    
    puts "Generating image embedding for product #{product_id}..."
    
    begin
      embedding = Personalization::ProductEmbeddingService.generate_single_product_embedding(
        product_id,
        embedding_type: 'image'
      )
      
      puts "✅ Successfully generated embedding (dimension: #{embedding.length})"
      
    rescue => e
      puts "❌ Failed to generate embedding: #{e.message}"
      exit 1
    end
  end

  desc "Check embedding statistics"
  task stats: :environment do
    puts "EMBEDDING STATISTICS"
    puts "="*30
    
    total_products = Product.joins(:shop)
                           .where("products.stock > 0")
                           .where("products.moderation_status = ?", "approved")
                           .where("products.image_url IS NOT NULL")
                           .where("products.image_url != ''")
                           .count
    
    total_embeddings = ProductEmbedding.count
    image_embeddings = ProductEmbedding.image_embeddings.count
    text_embeddings = ProductEmbedding.text_embeddings.count
    
    puts "Total products with images: #{total_products}"
    puts "Total embeddings: #{total_embeddings}"
    puts "  - Image embeddings: #{image_embeddings}"
    puts "  - Text embeddings: #{text_embeddings}"
    
    coverage = total_products > 0 ? (image_embeddings.to_f / total_products * 100).round(2) : 0
    puts "Image embedding coverage: #{coverage}%"
    
    if image_embeddings > 0
      latest_embedding = ProductEmbedding.image_embeddings.order(:created_at).last
      puts "Latest embedding: #{latest_embedding.created_at}"
    end
  end

  desc "Clean up old embeddings"
  task cleanup: :environment do
    puts "Cleaning up old embeddings..."
    
    # Remove embeddings for products that no longer exist
    orphaned_count = ProductEmbedding.left_joins(:product)
                                   .where(products: { id: nil })
                                   .count
    
    if orphaned_count > 0
      puts "Found #{orphaned_count} orphaned embeddings"
      ProductEmbedding.left_joins(:product)
                     .where(products: { id: nil })
                     .delete_all
      puts "✅ Cleaned up orphaned embeddings"
    else
      puts "No orphaned embeddings found"
    end
    
    # Remove embeddings for products without images
    no_image_count = ProductEmbedding.joins(:product)
                                   .where(products: { image_url: [nil, ''] })
                                   .count
    
    if no_image_count > 0
      puts "Found #{no_image_count} embeddings for products without images"
      ProductEmbedding.joins(:product)
                     .where(products: { image_url: [nil, ''] })
                     .delete_all
      puts "✅ Cleaned up embeddings for products without images"
    else
      puts "No embeddings found for products without images"
    end
  end

  desc "Test vision service connection"
  task test_vision_service: :environment do
    puts "Testing vision service connection..."
    
    vision_url = ENV.fetch("VISION_SERVICE_URL", "http://127.0.0.1:8001")
    
    begin
      uri = URI.parse("#{vision_url}/health")
      response = Net::HTTP.get_response(uri)
      
      if response.is_a?(Net::HTTPSuccess)
        health_data = JSON.parse(response.body)
        puts "✅ Vision service is healthy"
        puts "  Model: #{health_data['model']}"
        puts "  Device: #{health_data['device']}"
        puts "  Embedding dimension: #{health_data['embedding_dim']}"
      else
        puts "❌ Vision service health check failed: HTTP #{response.code}"
      end
      
    rescue => e
      puts "❌ Failed to connect to vision service: #{e.message}"
      puts "Make sure the vision service is running on #{vision_url}"
    end
  end
end