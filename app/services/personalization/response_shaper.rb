# frozen_string_literal: true

module Personalization
  class ResponseShaper
    def self.json(feed_id, plan_id, ttl, sections)
      {
        feed_id: feed_id,
        plan_id: plan_id,
        ttl_seconds: ttl,
        sections: sections.map do |section|
          {
            id: section[:id],
            title: section[:title],
            reason: section[:reason],
            items: section[:items].map(&:to_json),
            count: section[:items].count
          }
        end,
        metadata: {
          generated_at: Time.current,
          cache_hit: false,  # This would be set based on actual cache status
          total_latency_ms: 0  # This would be set based on actual timing
        }
      }
    end
    
    def self.sectioned_response(feed:, plan_id:, sections:, ttl_seconds:, is_cache_hit:, intent: nil, trace_versions: nil)
      response = {
        feed_id: feed.feed_uid,
        plan_id: plan_id,
        ttl_seconds: ttl_seconds,
        sections: sections.map do |section|
          {
            id: section[:id],
            title: section[:title],
            reason: section[:reason],
            products: section[:products],
            count: section[:products].count
          }
        end,
        trace: (trace_versions || { 
          prompt_version: feed.prompt_version, 
          model_version: feed.model_version, 
          index_version: feed.index_version 
        }),
        is_cache_hit: is_cache_hit,
        intent: intent
      }
      
      # Add experiment data if present
      if feed.experiment_key.present? && feed.variant.present?
        response[:experiment] = {
          key: feed.experiment_key,
          variant: feed.variant
        }
      end
      
      response
    end
    
    def self.build_lite_products(ids_as_strings)
      ids = Array(ids_as_strings).map { |v| v.to_s.strip }.reject(&:blank?).map(&:to_i)
      return [] if ids.empty?

      records = ::Product
                  .includes(:shop)
                  .where(id: ids)
                  .select(:id, :name, :price, :main_image, :supplementary_images, :shop_id)

      by_id = {}
      records.each do |p|
        supp       = coerce_images(p.supplementary_images)
        main       = main_image_or_fallback(p.main_image, supp)
        image_alias = main || supp.first

        by_id[p.id] = {
          id:   p.id,
          name: p.name.to_s,
          price: p.price.to_s,
          image: image_alias.to_s,
          main_image: main.to_s.presence,
          supplementary_images: supp,
          shop: {
            id: p.shop_id,
            name: p.shop&.name.to_s,
            store_logo_url: p.shop&.store_logo_url.to_s.presence
          }
        }
      end

      ids.map { |pid| by_id[pid] }.compact
    end
    
    private
    
    def self.coerce_images(val)
      arr =
        case val
        when Array then val
        when String
          begin
            parsed = JSON.parse(val)
            parsed.is_a?(Array) ? parsed : []
          rescue JSON::ParserError
            []
          end
        else
          []
        end
      arr.map { |u| u.to_s.presence }.compact.first(4)
    end

    def self.main_image_or_fallback(main_image, supp_arr)
      (main_image.to_s.presence) || supp_arr.first.to_s.presence
    end
  end
end

