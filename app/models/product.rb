# app/models/product.rb
class Product < ApplicationRecord
  belongs_to :shop
  belongs_to :category, optional: true
  belongs_to :brand,    optional: true   # <- add

  has_many :recommended_products,   dependent: :destroy
  has_many :moderation_events,      dependent: :destroy
  has_many :similar_products,       dependent: :delete_all
  has_many :similar_items,          through: :similar_products,      source: :similar
  has_many :complementary_products, dependent: :delete_all
  has_many :complementary_items,    through: :complementary_products, source: :complementary

  validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  after_create_commit :moderate_images!
  after_commit :enqueue_reembedding_if_relevant, on: %i[create update]

  def all_images
    [main_image, *(supplementary_images || [])].compact.uniq
  end

  def moderate_images!
    return true if ENV["SKIP_MODERATION"] == "1"
    return true unless defined?(ModerationService)

    results = all_images.map do |url|
      # Support both ModerationService.call(product, url, ...) and ModerationService.new(...).call
      if ModerationService.respond_to?(:call)
        ModerationService.call(self, url, user_id: shop.user_id)
      else
        ModerationService.new(self, url, user_id: shop.user_id).call
      end
    end

    if results.any? && results.all? { |r| r[:category] == "safe" }
      update!(
        moderation_status:     "approved",
        moderation_label:      "safe",
        moderation_confidence: results.map { |r| r[:confidence].to_f }.min
      )
    else
      worst = results.find { |r| r[:category] != "safe" } || {}
      update!(
        moderation_status:     "flagged",
        moderation_label:      worst[:category].presence || "unknown",
        moderation_confidence: worst[:confidence].to_f
      )
    end
  rescue => e
    # Never block creation; just mark as error and move on
    Rails.logger.warn("[moderation] product=#{id} soft-fail: #{e.class} #{e.message}")
    update_columns( # avoid triggering callbacks again
      moderation_status:     "error",
      moderation_label:      "error",
      moderation_confidence: 0.0,
      updated_at:            Time.current
    ) rescue nil
    true
  end

  private

  def enqueue_reembedding_if_relevant
    return if ENV["SKIP_EMBEDDINGS"] == "1"
    return unless defined?(Embeddings::ReembedProductJob)

    changed_relevant_fields =
      saved_change_to_name? ||
      saved_change_to_description? ||
      saved_change_to_brand_id? ||
      saved_change_to_category_id? ||
      saved_change_to_color? ||
      saved_change_to_size? ||
      saved_change_to_stock? ||
      saved_change_to_moderation_status?

    return unless changed_relevant_fields

    # The job re-checks approved/stock > 0 before writing vectors.
    Embeddings::ReembedProductJob.perform_later(id)
  rescue => e
    Rails.logger.warn("[embeddings] enqueue soft-fail product=#{id}: #{e.class} #{e.message}")
    true
  end
end
