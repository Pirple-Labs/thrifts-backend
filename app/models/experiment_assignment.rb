class ExperimentAssignment < ApplicationRecord
  belongs_to :experiment
  
  validates :variant, inclusion: { in: %w[control operator] }
  validates :user_id, uniqueness: { scope: :experiment_id }, allow_nil: true
  validates :session_id, uniqueness: { scope: :experiment_id }, allow_nil: true
  validate :either_user_or_session_present
  
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_session, ->(session_id) { where(session_id: session_id) }
  scope :control, -> { where(variant: 'control') }
  scope :operator, -> { where(variant: 'operator') }
  
  def subject_identifier
    user_id || session_id
  end
  
  def control?
    variant == 'control'
  end
  
  def operator?
    variant == 'operator'
  end
  
  private
  
  def either_user_or_session_present
    if user_id.blank? && session_id.blank?
      errors.add(:base, "Either user_id or session_id must be present")
    end
    
    if user_id.present? && session_id.present?
      errors.add(:base, "Cannot have both user_id and session_id")
    end
  end
end
