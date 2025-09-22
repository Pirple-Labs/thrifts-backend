# app/models/schema.rb
class Schema < ApplicationRecord
  self.primary_key = :id
  
  # Validations
  validates :id, presence: true, uniqueness: true
  validates :category, presence: true
  validates :schema_json, presence: true
  validates :version, presence: true
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :for_category, ->(category) { where(category: category) }
  scope :latest_version, -> { order(version: :desc) }
  
  # Class methods
  def self.for_category_latest(category)
    active.for_category(category).latest_version.first
  end
  
  def self.all_categories
    active.distinct.pluck(:category)
  end
  
  # Instance methods
  def fields
    schema_json['fields'] || []
  end
  
  def required_fields
    fields.select { |field| field['required'] }
  end
  
  def optional_fields
    fields.reject { |field| field['required'] }
  end
  
  def field_by_key(key)
    fields.find { |field| field['key'] == key }
  end
  
  def validate_product_data(product_data)
    errors = []
    
    # Check required fields
    required_fields.each do |field|
      key = field['key']
      if product_data[key].blank?
        errors << "#{field['label']} is required"
      end
    end
    
    # Validate field types
    fields.each do |field|
      key = field['key']
      value = product_data[key]
      next if value.blank?
      
      case field['type']
      when 'string'
        unless value.is_a?(String)
          errors << "#{field['label']} must be text"
        end
      when 'number'
        unless value.is_a?(Numeric)
          errors << "#{field['label']} must be a number"
        end
      when 'enum'
        unless field['options'].include?(value)
          errors << "#{field['label']} must be one of: #{field['options'].join(', ')}"
        end
      when 'date'
        begin
          Date.parse(value) if value.present?
        rescue ArgumentError
          errors << "#{field['label']} must be a valid date"
        end
      end
    end
    
    errors
  end
  
  # Seed data for MVP categories
  def self.seed_mvp_schemas
    schemas_data = [
      {
        id: 'fashion.v1',
        category: 'fashion',
        version: 'v1',
        description: 'Fashion product schema for clothing, shoes, and accessories',
        schema_json: {
          fields: [
            { key: 'brand', type: 'string', label: 'Brand', required: false, placeholder: 'e.g., Nike, Adidas' },
            { key: 'size', type: 'enum', label: 'Size', required: true, options: ['XS', 'S', 'M', 'L', 'XL', 'XXL', '28', '30', '32', '34', '36', '38', '40', '42', '44', '46', '48', '50'] },
            { key: 'color', type: 'string', label: 'Color', required: true, placeholder: 'e.g., Black, White, Red' },
            { key: 'material', type: 'string', label: 'Material', required: false, placeholder: 'e.g., Cotton, Leather, Denim' }
          ]
        }
      },
      {
        id: 'beauty.v1',
        category: 'beauty',
        version: 'v1',
        description: 'Beauty product schema for cosmetics, skincare, and personal care',
        schema_json: {
          fields: [
            { key: 'brand', type: 'string', label: 'Brand', required: false, placeholder: 'e.g., MAC, Maybelline, L\'Oreal' },
            { key: 'shade', type: 'string', label: 'Shade/Variant', required: false, placeholder: 'e.g., Ruby Red, Nude Beige' },
            { key: 'volume', type: 'string', label: 'Volume/Size', required: false, placeholder: 'e.g., 30ml, 50ml, 100ml' },
            { key: 'expiry_date', type: 'date', label: 'Expiry Date', required: false, placeholder: 'YYYY-MM-DD' }
          ]
        }
      },
      {
        id: 'electronics.v1',
        category: 'electronics',
        version: 'v1',
        description: 'Electronics product schema for gadgets, devices, and tech accessories',
        schema_json: {
          fields: [
            { key: 'brand', type: 'string', label: 'Brand', required: false, placeholder: 'e.g., Apple, Samsung, HP' },
            { key: 'model', type: 'string', label: 'Model', required: false, placeholder: 'e.g., iPhone 13, Galaxy S21' },
            { key: 'ram', type: 'string', label: 'RAM', required: false, placeholder: 'e.g., 8GB, 16GB' },
            { key: 'storage', type: 'string', label: 'Storage', required: false, placeholder: 'e.g., 128GB, 256GB, 512GB' },
            { key: 'battery_health', type: 'string', label: 'Battery Health', required: false, placeholder: 'e.g., 85%, 90%, 95%' },
            { key: 'warranty', type: 'string', label: 'Warranty', required: false, placeholder: 'e.g., 1 year, 2 years, No warranty' }
          ]
        }
      }
    ]
    
    schemas_data.each do |schema_data|
      find_or_create_by(id: schema_data[:id]) do |schema|
        schema.assign_attributes(schema_data)
      end
    end
  end
end
