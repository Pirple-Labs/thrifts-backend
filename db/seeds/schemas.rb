# db/seeds/schemas.rb
# Seed MVP schemas for Fashion, Beauty, and Electronics

puts "🌱 Seeding MVP schemas..."

# Clear existing schemas
Schema.destroy_all

# Fashion Schema
fashion_schema = Schema.create!(
  id: 'fashion.v1',
  category: 'fashion',
  version: 'v1',
  description: 'Fashion product schema for clothing, shoes, and accessories',
  active: true,
  schema_json: {
    fields: [
      {
        key: 'brand',
        type: 'string',
        label: 'Brand',
        required: false,
        placeholder: 'e.g., Nike, Adidas, Zara',
        max_length: 100
      },
      {
        key: 'size',
        type: 'enum',
        label: 'Size',
        required: true,
        options: ['XS', 'S', 'M', 'L', 'XL', 'XXL', '28', '30', '32', '34', '36', '38', '40', '42', '44', '46', '48', '50', '6', '7', '8', '9', '10', '11', '12']
      },
      {
        key: 'color',
        type: 'string',
        label: 'Color',
        required: true,
        placeholder: 'e.g., Black, White, Red, Navy Blue',
        max_length: 50
      },
      {
        key: 'material',
        type: 'string',
        label: 'Material',
        required: false,
        placeholder: 'e.g., Cotton, Leather, Denim, Polyester',
        max_length: 100
      }
    ]
  }
)

# Beauty Schema
beauty_schema = Schema.create!(
  id: 'beauty.v1',
  category: 'beauty',
  version: 'v1',
  description: 'Beauty product schema for cosmetics, skincare, and personal care',
  active: true,
  schema_json: {
    fields: [
      {
        key: 'brand',
        type: 'string',
        label: 'Brand',
        required: false,
        placeholder: 'e.g., MAC, Maybelline, L\'Oreal, Fenty Beauty',
        max_length: 100
      },
      {
        key: 'shade',
        type: 'string',
        label: 'Shade/Variant',
        required: false,
        placeholder: 'e.g., Ruby Red, Nude Beige, Warm Honey',
        max_length: 100
      },
      {
        key: 'volume',
        type: 'string',
        label: 'Volume/Size',
        required: false,
        placeholder: 'e.g., 30ml, 50ml, 100ml, 1.7oz',
        max_length: 50
      },
      {
        key: 'expiry_date',
        type: 'date',
        label: 'Expiry Date',
        required: false,
        placeholder: 'YYYY-MM-DD',
        min_date: Date.current.strftime('%Y-%m-%d')
      }
    ]
  }
)

# Electronics Schema
electronics_schema = Schema.create!(
  id: 'electronics.v1',
  category: 'electronics',
  version: 'v1',
  description: 'Electronics product schema for gadgets, devices, and tech accessories',
  active: true,
  schema_json: {
    fields: [
      {
        key: 'brand',
        type: 'string',
        label: 'Brand',
        required: false,
        placeholder: 'e.g., Apple, Samsung, HP, Dell',
        max_length: 100
      },
      {
        key: 'model',
        type: 'string',
        label: 'Model',
        required: false,
        placeholder: 'e.g., iPhone 13, Galaxy S21, MacBook Pro',
        max_length: 100
      },
      {
        key: 'ram',
        type: 'string',
        label: 'RAM',
        required: false,
        placeholder: 'e.g., 8GB, 16GB, 32GB',
        max_length: 20
      },
      {
        key: 'storage',
        type: 'string',
        label: 'Storage',
        required: false,
        placeholder: 'e.g., 128GB, 256GB, 512GB, 1TB',
        max_length: 20
      },
      {
        key: 'battery_health',
        type: 'string',
        label: 'Battery Health',
        required: false,
        placeholder: 'e.g., 85%, 90%, 95%',
        max_length: 10
      },
      {
        key: 'warranty',
        type: 'string',
        label: 'Warranty',
        required: false,
        placeholder: 'e.g., 1 year, 2 years, No warranty',
        max_length: 50
      }
    ]
  }
)

puts "✅ Created #{Schema.count} schemas:"
Schema.all.each do |schema|
  puts "   - #{schema.id} (#{schema.category}) - #{schema.fields.count} fields"
end

puts "🎯 Schema seeding completed!"
