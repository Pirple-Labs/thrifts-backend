# app/services/personalization/paginator.rb
# frozen_string_literal: true
require "base64"

module Personalization
  class Paginator
    def self.slice(items:, cursor:, limit:)
      offset = decode(cursor)
      slice  = items.slice(offset, limit) || []
      next_off = offset + slice.size
      {
        items: slice,
        index: (offset / limit) + 1,
        cursor: (next_off < items.size ? encode(next_off) : nil),
        has_more: next_off < items.size
      }
    end

    def self.encode(n); Base64.strict_encode64(n.to_i.to_s); end
    def self.decode(c); c.present? ? Base64.decode64(c).to_i : 0 rescue 0; end
  end
end
