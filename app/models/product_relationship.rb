# app/models/product_relationship.rb
# frozen_string_literal: true
#
# Model representing relationships between products for intelligent coordination
# This enables the system to understand how products work together
class ProductRelationship < ApplicationRecord
  belongs_to :product
  belongs_to :related_product, class_name: 'Product'
  
  # Relationship types
  RELATIONSHIP_TYPES = %w[complementary similar alternative].freeze
  
  validates :relationship_type, inclusion: { in: RELATIONSHIP_TYPES }
  validates :strength_score, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
  validates :context, presence: true
  
  # Ensure no duplicate relationships
  validates :product_id, uniqueness: { 
    scope: [:related_product_id, :relationship_type],
    message: "relationship already exists"
  }
  
  # Prevent self-referential relationships
  validate :no_self_reference
  
  # Scopes for different relationship types
  scope :complementary, -> { where(relationship_type: 'complementary') }
  scope :similar, -> { where(relationship_type: 'similar') }
  scope :alternative, -> { where(relationship_type: 'alternative') }
  
  # Scopes for strength filtering
  scope :strong, -> { where('strength_score >= ?', 0.8) }
  scope :medium, -> { where('strength_score >= ? AND strength_score < ?', 0.5, 0.8) }
  scope :weak, -> { where('strength_score < ?', 0.5) }
  
  # Find complementary products for a given product
  def self.complementary_for(product_id, limit: 10)
    where(product_id: product_id, relationship_type: 'complementary')
      .includes(:related_product)
      .order(strength_score: :desc)
      .limit(limit)
      .map(&:related_product)
  end
  
  # Find similar products for a given product
  def self.similar_to(product_id, limit: 10)
    where(product_id: product_id, relationship_type: 'similar')
      .includes(:related_product)
      .order(strength_score: :desc)
      .limit(limit)
      .map(&:related_product)
  end
  
  # Find alternative products for a given product
  def self.alternatives_to(product_id, limit: 10)
    where(product_id: product_id, relationship_type: 'alternative')
      .includes(:related_product)
      .order(strength_score: :desc)
      .limit(limit)
      .map(&:related_product)
  end
  
  # Find products that work well with a given product
  def self.coordinates_with(product_id, limit: 10)
    where(product_id: product_id)
      .includes(:related_product)
      .order(strength_score: :desc)
      .limit(limit)
      .map(&:related_product)
  end
  
  # Find products by use case compatibility
  def self.by_use_case(product_id, use_case, limit: 10)
    where(product_id: product_id)
      .where("context->>'use_case' = ?", use_case)
      .includes(:related_product)
      .order(strength_score: :desc)
      .limit(limit)
      .map(&:related_product)
  end
  
  # Find products by coordination reason
  def self.by_reason(product_id, reason, limit: 10)
    where(product_id: product_id)
      .where("context->>'reason' = ?", reason)
      .includes(:related_product)
      .order(strength_score: :desc)
      .limit(limit)
      .map(&:related_product)
  end
  
  # Create bidirectional relationship
  def self.create_bidirectional!(product:, related_product:, relationship_type:, strength_score:, context:)
    transaction do
      # Create forward relationship
      create!(
        product_id: product.id,
        related_product_id: related_product.id,
        relationship_type: relationship_type,
        strength_score: strength_score,
        context: context
      )
      
      # Create reverse relationship
      create!(
        product_id: related_product.id,
        related_product_id: product.id,
        relationship_type: relationship_type,
        strength_score: strength_score,
        context: context
      )
    end
  end
  
  # Update bidirectional relationship
  def self.update_bidirectional!(product:, related_product:, relationship_type:, strength_score:, context:)
    transaction do
      # Update forward relationship
      forward = find_by(
        product_id: product.id,
        related_product_id: related_product.id,
        relationship_type: relationship_type
      )
      
      if forward
        forward.update!(
          strength_score: strength_score,
          context: context
        )
      end
      
      # Update reverse relationship
      reverse = find_by(
        product_id: related_product.id,
        related_product_id: product.id,
        relationship_type: relationship_type
      )
      
      if reverse
        reverse.update!(
          strength_score: strength_score,
          context: context
        )
      end
    end
  end
  
  # Delete bidirectional relationship
  def self.delete_bidirectional!(product:, related_product:, relationship_type:)
    where(
      product_id: [product.id, related_product.id],
      related_product_id: [product.id, related_product.id],
      relationship_type: relationship_type
    ).destroy_all
  end
  
  private
  
  def no_self_reference
    if product_id == related_product_id
      errors.add(:related_product_id, "cannot reference the same product")
    end
  end
end

