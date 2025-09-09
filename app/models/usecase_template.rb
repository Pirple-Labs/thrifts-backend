# frozen_string_literal: true

class UsecaseTemplate < ApplicationRecord
  validates :template_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :slots, presence: true
  validates :rules, presence: true

  scope :for_template, ->(template_id) { where(template_id: template_id) }
end
