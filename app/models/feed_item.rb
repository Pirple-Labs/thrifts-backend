# app/models/feed_item.rb
class FeedItem < ApplicationRecord
  belongs_to :feed
  belongs_to :product
end
