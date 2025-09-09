# app/models/brand.rb
# frozen_string_literal: true
#
# Model representing product brands
class Brand < ApplicationRecord
  has_many :products, dependent: :nullify
  
  validates :name, presence: true, uniqueness: true
  
  # Brand categories: premium, budget, luxury, mid_range, standard
  validates :category, inclusion: { 
    in: %w[premium budget luxury mid_range standard], 
    allow_nil: true 
  }
  
  # Brand specializations: tech, fashion, beauty, home, general
  validates :specialization, inclusion: { 
    in: %w[tech fashion beauty home general], 
    allow_nil: true 
  }
  
  # Scopes for filtering
  scope :premium, -> { where(category: 'premium') }
  scope :budget, -> { where(category: 'budget') }
  scope :tech, -> { where(specialization: 'tech') }
  scope :fashion, -> { where(specialization: 'fashion') }
  scope :beauty, -> { where(specialization: 'beauty') }
  scope :home, -> { where(specialization: 'home') }
  
  # Helper methods
  def premium?
    category == 'premium'
  end
  
  def budget?
    category == 'budget'
  end
  
  def tech_brand?
    specialization == 'tech'
  end
  
  def fashion_brand?
    specialization == 'fashion'
  end
  
  def beauty_brand?
    specialization == 'beauty'
  end
  
  def home_brand?
    specialization == 'home'
  end
end

