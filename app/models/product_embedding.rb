class ProductEmbedding < ApplicationRecord
  belongs_to :product
  
  validates :product_id, presence: true, uniqueness: true
  validates :index_version, presence: true
  validates :embedded_at, presence: true
  
  scope :by_index_version, ->(version) { where(index_version: version) }
  scope :recent, ->(days = 7) { where('embedded_at >= ?', days.days.ago) }
  
  def self.find_similar_products(embedding_vector, limit: 50, similarity_threshold: 0.7, region: nil)
    # Find similar products using vector similarity
    # For now, use a simple approach since we don't have pgvector
    # In production, this would use proper vector similarity search
    
    # Get all embeddings and calculate similarity in Ruby
    # This is not optimal but works for demo purposes
    all_embeddings = joins(:product)
                     .joins('JOIN shops ON shops.id = products.shop_id')
                     .where('products.stock > 0')
                     .where('products.moderation_status = ?', 'approved')
    
    # Apply region filter if provided
    if region.present?
      all_embeddings = all_embeddings.where('shops.location = ?', region)
    end
    
    # Calculate similarities
    similarities = all_embeddings.map do |pe|
      similarity = cosine_similarity(embedding_vector, pe.embedding_array)
      {
        id: pe.product_id,
        similarity_score: similarity
      }
    end
    
    # Filter by threshold and sort
    similarities.select { |s| s[:similarity_score] >= similarity_threshold }
                .sort_by { |s| -s[:similarity_score] }
                .first(limit)
  end
  
  def self.store_embedding(product_id:, embedding_vector:, index_version: 'vec_dev_1')
    # Store or update embedding for a product
    embedding = find_or_initialize_by(product_id: product_id)
    
    embedding.assign_attributes(
      embedding: embedding_vector.to_s,
      index_version: index_version,
      embedded_at: Time.current
    )
    
    embedding.save!
    embedding
  end
  
  def similarity_to(other_embedding)
    return 0.0 if embedding.blank? || other_embedding.blank?
    
    # Calculate cosine similarity in Ruby
    self.class.cosine_similarity(embedding_array, other_embedding)
  end
  
  def embedding_array
    return [] if embedding.blank?
    
    # Parse the vector string back to array
    embedding.to_s.gsub(/[\[\]]/, '').split(',').map(&:to_f)
  end
  
  private
  
  def self.cosine_similarity(vec1, vec2)
    return 0.0 if vec1.blank? || vec2.blank? || vec1.length != vec2.length
    
    # Calculate dot product
    dot_product = vec1.zip(vec2).sum { |a, b| a * b }
    
    # Calculate magnitudes
    magnitude1 = Math.sqrt(vec1.sum { |x| x * x })
    magnitude2 = Math.sqrt(vec2.sum { |x| x * x })
    
    return 0.0 if magnitude1 == 0 || magnitude2 == 0
    
    # Calculate cosine similarity
    dot_product / (magnitude1 * magnitude2)
  end
end