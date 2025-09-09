# app/models/feed.rb
class Feed < ApplicationRecord
  belongs_to :user, optional: true
  has_many :feed_items, dependent: :destroy
  
  validates :feed_uid, presence: true, uniqueness: true
  validates :session_id, presence: true
  validates :page, presence: true
  validates :variant, inclusion: { in: %w[control operator llm] }, allow_nil: true
  
  scope :for_experiment, ->(experiment_key) { where(experiment_key: experiment_key) }
  scope :control, -> { where(variant: 'control') }
  scope :operator, -> { where(variant: 'operator') }
  scope :llm, -> { where(variant: 'llm') }
  
  def experiment_variant
    variant || 'control'
  end
  
  def in_experiment?
    experiment_key.present?
  end
  
  def control?
    variant == 'control'
  end
  
  def operator?
    variant == 'operator'
  end
end
