# frozen_string_literal: true

# Seed coordination data for the intelligent shopping assistant

puts "🌱 Seeding coordination data..."

# Create use case templates
templates = [
  {
    template_id: 'laptop_setup',
    name: 'Laptop Setup',
    slots: ['stand', 'mouse', 'bag', 'hub', 'monitor'],
    rules: {
      completion_threshold: 0.7,
      max_items_per_slot: 1,
      price_band_hint: 'mid',
      diversity_required: true
    }
  },
  {
    template_id: 'gaming_setup',
    name: 'Gaming Setup',
    slots: ['desk', 'chair', 'monitor', 'lighting', 'mouse_pad'],
    rules: {
      completion_threshold: 0.8,
      max_items_per_slot: 1,
      price_band_hint: 'mid',
      diversity_required: true
    }
  },
  {
    template_id: 'home_office',
    name: 'Home Office',
    slots: ['desk', 'chair', 'lamp', 'organizer', 'monitor'],
    rules: {
      completion_threshold: 0.6,
      max_items_per_slot: 1,
      price_band_hint: 'mid',
      diversity_required: true
    }
  },
  {
    template_id: 'phone_setup',
    name: 'Phone Setup',
    slots: ['case', 'protector', 'charger', 'mount'],
    rules: {
      completion_threshold: 0.5,
      max_items_per_slot: 1,
      price_band_hint: 'low',
      diversity_required: false
    }
  }
]

templates.each do |template_data|
  template = UsecaseTemplate.find_or_create_by(template_id: template_data[:template_id]) do |t|
    t.name = template_data[:name]
    t.slots = template_data[:slots]
    t.rules = template_data[:rules]
  end
  puts "✅ Created template: #{template.template_id}"
end

# Create sample product relations (simplified for demo)
puts "🔗 Creating sample product relations..."

# Get some sample products
laptops = Product.where("name ILIKE ?", "%laptop%").limit(3)
stands = Product.where("name ILIKE ?", "%stand%").limit(2)
mice = Product.where("name ILIKE ?", "%mouse%").limit(2)
bags = Product.where("name ILIKE ?", "%bag%").limit(2)
desks = Product.where("name ILIKE ?", "%desk%").limit(2)
chairs = Product.where("name ILIKE ?", "%chair%").limit(2)

# Create laptop setup relations
laptops.each do |laptop|
  stands.each do |stand|
    ProductRelation.find_or_create_by(
      seed_id: laptop.id,
      cand_id: stand.id,
      rel_type: 'complement',
      region: 'ke'
    ) do |rel|
      rel.score = 0.9
      rel.features = {
        co_purchase: 0.8,
        co_view: 0.7,
        embedding_similarity: 0.6,
        attribute_harmony: 0.9,
        recency: 0.8,
        price_fit: 0.7
      }
      rel.updated_at = Time.current
    end
  end

  mice.each do |mouse|
    ProductRelation.find_or_create_by(
      seed_id: laptop.id,
      cand_id: mouse.id,
      rel_type: 'complement',
      region: 'ke'
    ) do |rel|
      rel.score = 0.8
      rel.features = {
        co_purchase: 0.7,
        co_view: 0.8,
        embedding_similarity: 0.5,
        attribute_harmony: 0.8,
        recency: 0.7,
        price_fit: 0.8
      }
      rel.updated_at = Time.current
    end
  end

  bags.each do |bag|
    ProductRelation.find_or_create_by(
      seed_id: laptop.id,
      cand_id: bag.id,
      rel_type: 'complement',
      region: 'ke'
    ) do |rel|
      rel.score = 0.7
      rel.features = {
        co_purchase: 0.6,
        co_view: 0.7,
        embedding_similarity: 0.4,
        attribute_harmony: 0.7,
        recency: 0.6,
        price_fit: 0.9
      }
      rel.updated_at = Time.current
    end
  end
end

# Create gaming setup relations
chairs.each do |chair|
  desks.each do |desk|
    ProductRelation.find_or_create_by(
      seed_id: chair.id,
      cand_id: desk.id,
      rel_type: 'complement',
      region: 'ke'
    ) do |rel|
      rel.score = 0.9
      rel.features = {
        co_purchase: 0.8,
        co_view: 0.7,
        embedding_similarity: 0.6,
        attribute_harmony: 0.9,
        recency: 0.8,
        price_fit: 0.7
      }
      rel.updated_at = Time.current
    end
  end
end

puts "✅ Created #{ProductRelation.count} product relations"

# Create some sample overrides (boost/block)
puts "🎯 Creating sample overrides..."

# Boost some laptop + stand combinations
if laptops.any? && stands.any?
  ProductRelationOverride.find_or_create_by(
    seed_id: laptops.first.id,
    cand_id: stands.first.id
  ) do |override|
    override.action = 'boost'
    override.weight = 0.3
    override.note = 'High-quality laptop stand combination'
  end
end

puts "✅ Created #{ProductRelationOverride.count} overrides"

puts "🎉 Coordination data seeding complete!"
puts "📊 Summary:"
puts "   - Templates: #{UsecaseTemplate.count}"
puts "   - Relations: #{ProductRelation.count}"
puts "   - Overrides: #{ProductRelationOverride.count}"



