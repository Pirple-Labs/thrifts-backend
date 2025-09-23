class ImageSearchPerformance < ApplicationRecord
  validates :image_url, presence: true
  validates :plan_id, presence: true
  validates :results_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :cache_hit, inclusion: { in: [true, false] }
  validates :duration_ms, presence: true, numericality: { greater_than: 0 }
  
  scope :recent, ->(timeframe = 1.hour) { where('created_at >= ?', timeframe.ago) }
  scope :successful, -> { where('results_count > 0') }
  scope :failed, -> { where('results_count = 0') }
  scope :cached, -> { where(cache_hit: true) }
  scope :uncached, -> { where(cache_hit: false) }
  
  def self.track_search!(image_url:, plan_id:, results_count:, cache_hit:, duration_ms:)
    create!(
      image_url: image_url,
      plan_id: plan_id,
      results_count: results_count,
      cache_hit: cache_hit,
      duration_ms: duration_ms
    )
  rescue => e
    Rails.logger.error "Failed to track image search performance: #{e.message}"
  end
  
  def self.performance_report(timeframe: 1.hour)
    recent_searches = recent(timeframe)
    
    {
      total_searches: recent_searches.count,
      successful_searches: recent_searches.successful.count,
      failed_searches: recent_searches.failed.count,
      cache_hit_rate: cache_hit_rate(timeframe),
      avg_duration_ms: recent_searches.average(:duration_ms).to_f.round(2),
      avg_results_count: recent_searches.successful.average(:results_count).to_f.round(2),
      p95_duration_ms: percentile_duration(recent_searches, 95),
      p99_duration_ms: percentile_duration(recent_searches, 99)
    }
  end
  
  def self.cache_hit_rate(timeframe: 1.hour)
    recent_searches = recent(timeframe)
    return 0.0 if recent_searches.empty?
    
    (recent_searches.cached.count.to_f / recent_searches.count * 100).round(2)
  end
  
  private
  
  def self.percentile_duration(searches, percentile)
    durations = searches.pluck(:duration_ms).sort
    return 0 if durations.empty?
    
    index = (percentile / 100.0 * (durations.length - 1)).round
    durations[index] || durations.last
  end
end





