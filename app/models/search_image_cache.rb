class SearchImageCache < ApplicationRecord
  validates :cache_key, presence: true, uniqueness: true
  validates :public_id, presence: true
  validates :transform_params, presence: true
  validates :version, presence: true
  validates :embedding, presence: true
  
  scope :by_version, ->(version) { where(version: version) }
  scope :recent, ->(days = 7) { where('last_accessed_at >= ?', days.days.ago) }
  scope :popular, ->(min_hits = 5) { where('hit_count >= ?', min_hits) }
  
  def self.find_embedding(cache_key)
    record = find_by(cache_key: cache_key)
    return nil unless record
    
    # Update access stats
    record.increment!(:hit_count)
    record.touch(:last_accessed_at)
    
    record.embedding
  end
  
  def self.store_embedding(cache_key:, public_id:, transform_params:, version:, embedding:)
    create!(
      cache_key: cache_key,
      public_id: public_id,
      transform_params: transform_params,
      version: version,
      embedding: embedding,
      hit_count: 0,
      last_accessed_at: Time.current
    )
  rescue ActiveRecord::RecordNotUnique
    # Handle race condition - another process stored it first
    find_embedding(cache_key)
  end
  
  def self.cleanup_old_entries!(days: 30, min_hits: 5)
    where('last_accessed_at < ? AND hit_count < ?', days.days.ago, min_hits)
      .delete_all
  end
  
  def self.cache_stats
    {
      total_entries: count,
      popular_entries: popular.count,
      recent_entries: recent.count,
      avg_hit_count: average(:hit_count).to_f.round(2),
      oldest_entry: minimum(:created_at),
      newest_entry: maximum(:created_at)
    }
  end
  
  def embedding_similarity(other_embedding)
    return 0.0 if embedding.blank? || other_embedding.blank?
    
    # Calculate cosine similarity using pgvector
    self.class.connection.select_value(
      "SELECT 1 - (? <=> ?::vector)",
      embedding.to_s,
      other_embedding.to_s
    ).to_f
  end
end
