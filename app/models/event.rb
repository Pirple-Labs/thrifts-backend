# app/models/event.rb
class Event < ApplicationRecord
  belongs_to :user, optional: true

  PAGES = %w[home pdp profile cart checkout].freeze

  validates :event_id,  presence: true
  validates :event_name, presence: true
  validates :session_id, presence: true
  validates :page, inclusion: { in: PAGES }
end
