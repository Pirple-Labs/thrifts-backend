# app/models/playbook.rb
# frozen_string_literal: true

class Playbook < ApplicationRecord
  belongs_to :user, optional: true
  
  validates :playbook_id, presence: true, uniqueness: true
  validates :page, presence: true, inclusion: { in: %w[home pdp wishlist checkout profile] }
  validates :valid_for_hours, presence: true, numericality: { greater_than: 0 }
  validates :generated_at, presence: true
  validates :ai_generated, inclusion: { in: [true, false] }
  
  # Scopes
  scope :active, -> { where('generated_at > ?', 48.hours.ago) }
  scope :for_page, ->(page) { where(page: page) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :ai_generated, -> { where(ai_generated: true) }
  scope :control, -> { where(ai_generated: false) }
  
  # JSON columns are handled natively by ActiveRecord (json/jsonb). No manual serialization needed.
  
  def expired?
    generated_at < valid_for_hours.hours.ago
  end
  
  def active?
    !expired?
  end
  
  def expires_at
    generated_at + valid_for_hours.hours
  end
  
  def time_until_expiry
    expires_at - Time.current
  end
  
  def self.find_active_for_user_and_page(user_id, page)
    where(user_id: user_id, page: page)
      .active
      .order(generated_at: :desc)
      .first
  end
  
  def self.find_active_for_cohort_and_page(cohort_id, page)
    where(cohort_id: cohort_id, page: page)
      .active
      .order(generated_at: :desc)
      .first
  end
  
  def self.generate_playbook_id(user_id, page, timestamp = Time.current)
    "pb_#{timestamp.strftime('%Y-%m-%d')}_#{user_id || 'anon'}_#{page}"
  end
end

