# lib/tasks/schema_setup.rake
namespace :schema do
  desc "Setup schema system - run migrations and seed schemas"
  task setup: :environment do
    puts "🚀 Setting up schema system..."
    
    # Run migrations
    puts "📦 Running migrations..."
    Rake::Task['db:migrate'].invoke
    
    # Seed schemas
    puts "🌱 Seeding schemas..."
    load Rails.root.join('db', 'seeds', 'schemas.rb')
    
    puts "✅ Schema system setup completed!"
  end
  
  desc "Seed MVP schemas"
  task seed: :environment do
    puts "🌱 Seeding MVP schemas..."
    load Rails.root.join('db', 'seeds', 'schemas.rb')
  end
  
  desc "Validate all existing products against their schemas"
  task validate_products: :environment do
    puts "🔍 Validating existing products..."
    
    schema_products = Product.where.not(schema_version: nil)
    total = schema_products.count
    valid = 0
    invalid = 0
    
    schema_products.find_each do |product|
      if product.can_publish?
        valid += 1
      else
        invalid += 1
        puts "❌ Product #{product.id} (#{product.name}) - #{product.schema_validation_errors.join(', ')}"
      end
    end
    
    puts "📊 Validation Results:"
    puts "   Total schema products: #{total}"
    puts "   Valid: #{valid}"
    puts "   Invalid: #{invalid}"
  end
  
  desc "Show schema information"
  task info: :environment do
    puts "📋 Schema System Information:"
    puts "   Total schemas: #{Schema.count}"
    puts "   Active schemas: #{Schema.active.count}"
    puts "   Categories: #{Schema.all_categories.join(', ')}"
    
    puts "\n📝 Schema Details:"
    Schema.active.each do |schema|
      puts "   #{schema.id} (#{schema.category})"
      puts "     Fields: #{schema.fields.count}"
      puts "     Required: #{schema.required_fields.count}"
      puts "     Optional: #{schema.optional_fields.count}"
    end
    
    puts "\n📦 Product Statistics:"
    puts "   Total products: #{Product.count}"
    puts "   Schema products: #{Product.where.not(schema_version: nil).count}"
    puts "   Legacy products: #{Product.where(schema_version: nil).count}"
    puts "   Draft products: #{Product.where(status: 'draft').count}"
    puts "   Published products: #{Product.where(status: 'published').count}"
  end
end
