# app/services/personalization/slate_writer.rb
# frozen_string_literal: true
require "securerandom"

module Personalization
  class SlateWriter
    def self.persist!(snapshot:, fingerprint:, ranked_items:, ttl_seconds:, versions:, plan_id:, experiment_key: nil, variant: nil)
      feed = Feed.create!(
        feed_uid:       SecureRandom.uuid,
        user_id:        snapshot["user_id"],
        session_id:     snapshot["session_id"],
        page:           snapshot["page"],
        plan_id:        plan_id,
        experiment_key: experiment_key,
        variant:        variant,
        intent_label:   nil,
        intent_confidence: nil,
        constraints:    { pickup_only: snapshot["pickup_only"], region: snapshot["region"], geohash6: snapshot["geohash6"] }.compact,
        ttl_seconds:    ttl_seconds,
        is_cache_hit:   false,
        prompt_version: versions[:prompt_version],
        model_version:  versions[:model_version],
        index_version:  versions[:index_version],
        fingerprint:    fingerprint
      )

      reasons_map = {}
      rows = ranked_items.each_with_index.map do |r, idx|
        reasons_map[r[:id].to_s] = r[:reason].to_s
        {
          feed_id:     feed.id,
          product_id:  r[:id],
          section:     "grid",
          position:    idx + 1,
          reason:      r[:reason],
          matched_phrase: r[:matched_phrase],
          vec_score:   r[:vec_score],
          weight:      r[:weight],
          role:        r[:role],
          final_score: r[:final_score],
          created_at:  Time.current, updated_at: Time.current
        }
      end
      FeedItem.insert_all!(rows) if rows.any?

      [feed, reasons_map]
    end
  end
end
