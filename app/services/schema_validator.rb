# app/services/schema_validator.rb
class SchemaValidator
  def initialize(schema)
    @schema = schema
  end
  
  def validate(product_data)
    errors = []
    
    # Check required fields
    @schema.required_fields.each do |field|
      key = field['key']
      if product_data[key].blank?
        errors << "#{field['label']} is required"
      end
    end
    
    # Validate field types and constraints
    @schema.fields.each do |field|
      key = field['key']
      value = product_data[key]
      next if value.blank?
      
      case field['type']
      when 'string'
        unless value.is_a?(String)
          errors << "#{field['label']} must be text"
        end
        
        # Check string length constraints
        if field['max_length'] && value.length > field['max_length']
          errors << "#{field['label']} must be #{field['max_length']} characters or less"
        end
        
        if field['min_length'] && value.length < field['min_length']
          errors << "#{field['label']} must be at least #{field['min_length']} characters"
        end
        
      when 'number'
        unless value.is_a?(Numeric)
          errors << "#{field['label']} must be a number"
        end
        
        # Check numeric constraints
        if field['min'] && value < field['min']
          errors << "#{field['label']} must be at least #{field['min']}"
        end
        
        if field['max'] && value > field['max']
          errors << "#{field['label']} must be at most #{field['max']}"
        end
        
      when 'enum'
        unless field['options'].include?(value)
          errors << "#{field['label']} must be one of: #{field['options'].join(', ')}"
        end
        
      when 'date'
        begin
          parsed_date = Date.parse(value) if value.present?
          
          # Check date constraints
          if field['min_date'] && parsed_date < Date.parse(field['min_date'])
            errors << "#{field['label']} must be after #{field['min_date']}"
          end
          
          if field['max_date'] && parsed_date > Date.parse(field['max_date'])
            errors << "#{field['label']} must be before #{field['max_date']}"
          end
        rescue ArgumentError
          errors << "#{field['label']} must be a valid date (YYYY-MM-DD)"
        end
        
      when 'boolean'
        unless [true, false, 'true', 'false', '1', '0'].include?(value)
          errors << "#{field['label']} must be true or false"
        end
      end
    end
    
    errors
  end
  
  def valid?(product_data)
    validate(product_data).empty?
  end
  
  def self.validate_product(product)
    return [] unless product.schema_version
    
    schema = Schema.find_by(id: product.schema_version)
    return ["Schema not found: #{product.schema_version}"] unless schema
    
    validator = new(schema)
    validator.validate(product.attributes || {})
  end
end
