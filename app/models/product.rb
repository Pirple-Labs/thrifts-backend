# app/models/product.rb
class Product < ApplicationRecord
  belongs_to :shop
  belongs_to :category, optional: true

  has_many :recommended_products,    dependent: :destroy
  has_many :moderation_events,       dependent: :destroy

  has_many :similar_products,        dependent: :delete_all
  has_many :similar_items,
           through: :similar_products,
           source:  :similar

  has_many :complementary_products,  dependent: :delete_all
  has_many :complementary_items,
           through: :complementary_products,
           source:  :complementary

  # 🔒 Inventory check
  validates :stock,
            numericality: { only_integer: true,
                            greater_than_or_equal_to: 0 }

  # 1️⃣ On create, moderate images immediately
  after_create_commit :moderate_images!

  # 2️⃣ On create OR update, re‑index this product’s embedding
  after_commit :reindex_embedding!, on: %i[create update]

  def all_images
    [main_image, *(supplementary_images || [])].compact
  end

  def moderate_images!
    results = all_images.map do |url|
      ModerationService.new(self, url, user_id: shop.user_id).call
    end

    if results.all? { |r| r[:category] == "safe" }
      update!(
        moderation_status:    "approved",
        moderation_label:     "safe",
        moderation_confidence: results.map { |r| r[:confidence].to_f }.min
      )
    else
      worst = results.find { |r| r[:category] != "safe" }
      update!(
        moderation_status:    "flagged",
        moderation_label:     worst[:category],
        moderation_confidence: worst[:confidence].to_f
      )
    end
  rescue => e
    update!(
      moderation_status:    "error",
      moderation_label:     "error",
      moderation_confidence: 0.0
    )
    Rails.logger.error("Moderation failed for Product #{id}: #{e.message}")
  end

  private

  def reindex_embedding!
    # Use this product’s updated_at as the `since` timestamp
    since = updated_at.iso8601
    Rails.logger.info("[Product] Re‑indexing embedding for ##{id} since #{since}")

    # Shell out to your Python script in delta mode
    cmd = "python -m agent.recommend.embed_catalog --since #{since}"
    success = system(cmd)

    if success
      Rails.logger.info("[Product] Embedding re‑index succeeded for ##{id}")
    else
      Rails.logger.error("[Product] Embedding re‑index FAILED for ##{id}")
    end
  rescue => e
    Rails.logger.error("[Product] Exception reindexing ##{id}: #{e.message}")
  end
end
