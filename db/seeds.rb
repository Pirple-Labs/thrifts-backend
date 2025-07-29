require "csv"

# === Step 0: Clear existing records ===
Product.delete_all
Category.delete_all
puts "🗑️  Cleared existing products and categories."

# === Step 1: Ensure Jesse Mutua has a shop ===
jesse = User.find(46)
shop = jesse.shop || Shop.create!(user: jesse, name: "Jesse's Shop")
puts "🛒 Seeding products to: #{shop.name} (User ID: #{jesse.id})"

# === Step 2: Seed base categories ===
category_names = [
  "Women’s Clothing", "Men’s Clothing", "Kids & Babywear", "Footwear",
  "Bags & Accessories", "Home & Kitchen", "Electronics & Gadgets",
  "Books & Media", "Beauty & Personal Care", "Event & Vintage Wear"
]

category_lookup = {}
category_names.each do |name|
  record = Category.create!(name: name)
  # Normalize to lowercase, alphanumeric + underscore
  normalized_key = name.downcase.gsub(/[^a-z0-9]/, "_")
  category_lookup[normalized_key] = record.id
end
puts "✅ Seeded #{category_lookup.size} categories."

# === Step 3: CSV to readable category map ===
CSV_TO_CATEGORY_MAP = {
  "women_dresses" => "Women’s Clothing",
  "men_shirts" => "Men’s Clothing",
  "kids" => "Kids & Babywear",
  "shoes" => "Footwear",
  "bags" => "Bags & Accessories",
  "home_decor" => "Home & Kitchen",
  "kitchen" => "Home & Kitchen",
  "phones" => "Electronics & Gadgets",
  "computers" => "Electronics & Gadgets",
  "televisions" => "Electronics & Gadgets",
  "books" => "Books & Media",
  "beauty" => "Beauty & Personal Care",
  "event_wear" => "Event & Vintage Wear"
}

# === Step 4: Load CSV and chunk into groups of 3 ===
file_path = Rails.root.join("./db/uploaded_products.csv")
rows = CSV.read(file_path, headers: true)
chunks = rows.each_slice(3).to_a
seeded_count = 0

chunks.each do |group|
  rep = group[0]
  original_slug = rep["category"]
  mapped_category = CSV_TO_CATEGORY_MAP[original_slug]

  if mapped_category.nil?
    puts "⚠️  Unmapped CSV category: '#{original_slug}'"
    next
  end

  normalized_key = mapped_category.downcase.gsub(/[^a-z0-9]/, "_")
  category_id = category_lookup[normalized_key]

  unless category_id
    puts "⚠️  Failed to find category_id for '#{mapped_category}' → normalized key '#{normalized_key}'"
    next
  end

  main_image = rep["image_url"]
  supplementary = group[1..2].map { |r| r["image_url"] }.compact

  Product.create!(
    name: rep["name"].titleize,
    main_image: main_image,
    supplementary_images: supplementary,
    category_id: category_id,
    shop_id: shop.id,
    price: rand(20.0..200.0).round(2),
    description: "Imported product from #{mapped_category}.",
    color: ["Red", "Black", "Blue", "White", "Green", "Gray"].sample,
    size: ["S", "M", "L", "XL"].sample,
    stock: rand(10..100),
    moderation_status: "pending",
    views: 0
  )

  seeded_count += 1
end

puts "✅ Seeded #{seeded_count} products from #{rows.size} images."
