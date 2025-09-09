# app/jobs/embeddings/reembed_product_job.rb
# frozen_string_literal: true

module Embeddings
  class ReembedProductJob < ApplicationJob
    queue_as :default

    def perform(product_id)
      p = Product.find_by(id: product_id)
      return unless p
      return unless p.moderation_status == "approved" && p.stock.to_i > 0

      text = canonical_text(p)
      vec  = Embeddings::OpenAIClient.embed([text]).first
      return unless vec

      ProductEmbedding.upsert(
        {
          product_id:    p.id,
          embedding:     vec,
          index_version: ENV.fetch("INDEX_VERSION", "vec_#{Time.now.utc.utc.strftime('%Y_%m_%d')}"),
          embedded_at:   Time.current,
          created_at:    Time.current,
          updated_at:    Time.current
        },
        unique_by: :index_product_embeddings_on_product_id
      )
    end

    private

    def canonical_text(p)
      parts = []
      parts << p.name if p.name.present?
      parts << p.description if p.description.present?
      parts << "Brand: #{Brand.find_by(id: p.brand_id)&.name}" if p.brand_id.present?
      parts << "Category: #{Category.find_by(id: p.category_id)&.name}" if p.category_id.present?
      parts << "Color: #{p.color}" if p.color.present?
      parts << "Size: #{p.size}" if p.size.present?
      parts.compact.join(". ")
    end
  end
end
