class Experiment < ApplicationRecord
  has_many :experiment_assignments, dependent: :destroy
  
  validates :key, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[draft running paused complete] }
  validates :traffic_pct, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  
  scope :running, -> { where(status: 'running') }
  scope :active, -> { where(status: ['running', 'paused']) }
  
  def running?
    status == 'running'
  end
  
  def paused?
    status == 'paused'
  end
  
  def complete?
    status == 'complete'
  end
  
  def draft?
    status == 'draft'
  end
  
  def start!
    update!(status: 'running')
  end
  
  def pause!
    update!(status: 'paused')
  end
  
  def complete!
    update!(status: 'complete')
  end
  
  def traffic_fraction
    traffic_pct / 100.0
  end
end
