# app/services/personalization/fingerprint_cache.rb
# frozen_string_literal: true
require "digest"

module Personalization
  class FingerprintCache
    KEY_BY_FP   = "feed:fp:%s"
    KEY_BY_FEED = "feed:uid:%s"

    def self.fingerprint(snapshot:, versions:)
      Digest::SHA256.hexdigest({ snapshot:, versions: }.to_json)
    end

    def self.reuse_feed(fingerprint:, ttl_seconds:)
      entry = Rails.cache.read(KEY_BY_FP % fingerprint)
      return nil unless entry.present?
      feed = Feed.find_by(feed_uid: entry[:feed_uid])
      return nil unless feed
      {
        feed: feed,
        items: entry[:items],
        reasons: entry[:reasons],
        plan_id: entry[:plan_id] || feed.plan_id,
        plan_sections: entry[:plan_sections],
        snapshot: entry[:snapshot]
      }
    end

    def self.store!(fingerprint:, feed:, items:, reasons:, ttl_seconds:, plan_sections: nil, snapshot: nil)
      payload = { feed_uid: feed.feed_uid, items: items, reasons: reasons, plan_id: feed.plan_id }
      payload[:plan_sections] = plan_sections if plan_sections
      payload[:snapshot] = snapshot if snapshot

      Rails.cache.write(KEY_BY_FP % fingerprint, payload, expires_in: ttl_seconds.seconds)
      Rails.cache.write(KEY_BY_FEED % feed.feed_uid, payload.except(:feed_uid), expires_in: ttl_seconds.seconds)
    end

    def self.fetch_by_feed(feed:)
      Rails.cache.read(KEY_BY_FEED % feed.feed_uid)
    end
  end
end
