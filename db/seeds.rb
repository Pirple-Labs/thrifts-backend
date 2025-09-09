# frozen_string_literal: true
require "csv"
require "securerandom"
require "bigdecimal/util"

APPROVE_ALL      = true
PICKUP_READY_ALL = true
DEFAULT_REGION   = "Nairobi"

# Wipe products/categories only (keep users/shops)
Product.delete_all
Category.delete_all
puts "🗑️  Cleared products & categories."

# === Step 1: Ensure we have a user and a valid shop ===
jesse = User.find_by(id: 1) || User.first || User.create!(
  email: "seed+owner@thrifts.local", password: "password123", name: "Seed Owner"
)

shop = Shop.find_or_initialize_by(user: jesse)
shop.name          ||= "Jesse's Shop"
shop.description   ||= "Seeded pickup-only shop in Nairobi."
shop.location      ||= DEFAULT_REGION # feed uses region/location filters
shop.phone         ||= "0700000000"   # if validated
shop.pickup_agent  ||= "Front Desk"   # if validated
shop.agreed = true if shop.has_attribute?(:agreed) && shop.agreed.nil?
shop.save!

puts "🛒 Seeding products to: #{shop.name} (User ID: #{jesse.id}, Shop ID: #{shop.id}, Location: #{shop.location})"

# === Step 2: Base categories ===
category_names = [
  "Women’s Clothing", "Men’s Clothing", "Kids & Babywear", "Footwear",
  "Bags & Accessories", "Home & Kitchen", "Electronics & Gadgets",
  "Books & Media", "Beauty & Personal Care", "Event & Vintage Wear"
]
category_lookup = {}
category_names.each do |name|
  rec = Category.find_or_create_by!(name: name)
  key = name.downcase.gsub(/[^a-z0-9]/, "_")
  category_lookup[key] = rec.id
end
puts "✅ Categories ready (#{category_lookup.size})."

# === Step 3: CSV category map ===
CSV_TO_CATEGORY_MAP = {
  "women_dresses" => "Women’s Clothing",
  "men_shirts"    => "Men’s Clothing",
  "kids"          => "Kids & Babywear",
  "shoes"         => "Footwear",
  "bags"          => "Bags & Accessories",
  "home_decor"    => "Home & Kitchen",
  "kitchen"       => "Home & Kitchen",
  "phones"        => "Electronics & Gadgets",
  "computers"     => "Electronics & Gadgets",
  "televisions"   => "Electronics & Gadgets",
  "books"         => "Books & Media",
  "beauty"        => "Beauty & Personal Care",
  "event_wear"    => "Event & Vintage Wear"
}.freeze

def normalize_key(str) = str.to_s.downcase.gsub(/[^a-z0-9]/, "_")

def map_category_id(csv_cat, lookup)
  return nil if csv_cat.blank?

  mapped = CSV_TO_CATEGORY_MAP[csv_cat.to_s]
  if mapped.present?
    return lookup[normalize_key(mapped)]
  end

  # treat CSV category as a display name, create if missing
  key = normalize_key(csv_cat)
  lookup[key] ||= Category.find_or_create_by!(name: csv_cat.to_s).id
end

# === Step 4: Load CSV ===
file_path = Rails.root.join("db/uploaded_products.csv")
abort "❌ CSV not found at #{file_path}" unless File.exist?(file_path)

rows = CSV.read(file_path, headers: true, encoding: "utf-8")
puts "📄 CSV rows: #{rows.size}"

# === Step 5: Seed products ===
seeded  = 0
skipped = 0

ActiveRecord::Base.transaction do
  # if CSV has image1/image_1 columns, we treat each row as one product with multi images;
  # otherwise fallback to legacy "3 rows = 1 product" using image_url.
  supports_multi = rows.headers.any? { |h| %w[image1 image_1].include?(h.to_s.downcase) }

  if supports_multi
    rows.each do |r|
      name       = r["name"].presence || "Untitled #{SecureRandom.hex(3)}"
      category   = r["category"]
      image1     = r["image1"] || r["image_1"] || r["main_image"] || r["image_url"]
      image2     = r["image2"] || r["image_2"]
      image3     = r["image3"] || r["image_3"]
      cat_id     = map_category_id(category, category_lookup)

      if image1.blank?
        puts "⚠️  Skip '#{name}': missing main image"
        skipped += 1
        next
      end

      unless cat_id
        puts "⚠️  Unknown category '#{category}' — skipping"
        skipped += 1
        next
      end

      supplementary = [image2, image3].compact_blank
      price_str     = r["price"].presence
      price         = (price_str ? price_str.to_d : rand(20.0..200.0).round(2))

      description   = r["description"].presence || "Imported product."
      color         = r["color"].presence || %w[Red Black Blue White Green Gray].sample
      size          = r["size"].presence || %w[S M L XL].sample
      stock         = (r["stock"].presence || rand(10..100)).to_i

      p = Product.new(
        name: name.to_s.strip,
        main_image: image1,
        supplementary_images: supplementary,
        category_id: cat_id,
        shop_id: shop.id,
        price: price,
        description: description,
        color: color,
        size: size,
        stock: stock,
        moderation_status: (APPROVE_ALL ? "approved" : "pending"),
        pickup_ready: (PICKUP_READY_ALL ? true : false),
        views: 0
      )
      if p.valid?
        p.save!
        seeded += 1
      else
        puts "❌ Skip '#{name}': #{p.errors.full_messages.join(", ")}"
        skipped += 1
      end
    end
  else
    # Legacy format: every 3 rows make one product (image_url)
    rows.each_slice(3) do |group|
      rep = group[0]
      next unless rep

      original      = rep["category"]
      cat_id        = map_category_id(original, category_lookup)
      unless cat_id
        puts "⚠️  Unmapped category '#{original}' — skipping group"
        skipped += 1
        next
      end

      main_image    = rep["image_url"].presence
      if main_image.blank?
        puts "⚠️  Skipping group: missing main image"
        skipped += 1
        next
      end
      supplementary = group[1..2].to_a.map { |g| g["image_url"].presence }.compact_blank
      name          = (rep["name"].presence || "Untitled #{SecureRandom.hex(3)}").to_s

      p = Product.new(
        name: name.titleize,
        main_image: main_image,
        supplementary_images: supplementary,
        category_id: cat_id,
        shop_id: shop.id,
        price: rand(20.0..200.0).round(2),
        description: "Imported product from #{original}.",
        color: %w[Red Black Blue White Green Gray].sample,
        size: %w[S M L XL].sample,
        stock: rand(10..100),
        moderation_status: (APPROVE_ALL ? "approved" : "pending"),
        pickup_ready: (PICKUP_READY_ALL ? true : false),
        views: 0
      )
      if p.valid?
        p.save!
        seeded += 1
      else
        puts "❌ Skip '#{name}': #{p.errors.full_messages.join(", ")}"
        skipped += 1
      end
    end
  end
end

puts "✅ Seeded #{seeded} products. (Skipped: #{skipped})"
