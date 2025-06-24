# db/seeds.rb
require 'faker'

puts "🌱 Seeding..."

# Wipe dependent records only (preserve users and shops)
OrderItem.destroy_all
Order.destroy_all
RecommendedProduct.destroy_all
Product.destroy_all
Category.destroy_all

puts "✅ Cleared orders, products, categories."

# === Seed categories ===
category_names = ["Clothing", "Electronics", "Books", "Shoes", "Home Decor"]
categories = category_names.map { |name| Category.find_or_create_by!(name: name) }
puts "✅ Seeded #{categories.size} categories."

# === Find merchant ===
merchant = User.find_by(email: "jessemutua76@gmail.com")
raise "Merchant not found!" unless merchant

shop = merchant.shop
raise "Shop for merchant not found!" unless shop

# === Seed products to existing shop ===
10.times do |i|
  Product.create!(
    name: Faker::Commerce.product_name,
    main_image: "https://loremflickr.com/300/300/product?lock=#{i}",
    supplementary_images: ["https://loremflickr.com/300/300/item?lock=#{i + 100}"],
    price: Faker::Commerce.price(range: 1000.0..15000.0),
    description: Faker::Lorem.sentence(word_count: 12),
    views: rand(10..1000),
    shop: shop,
    category: categories.sample
  )
end

puts "✅ Added 10 products to #{shop.name}"

# === Create dummy buyer ===
buyer = User.find_or_create_by!(email: "dummybuyer@example.com") do |u|
  u.password = "password123"
end

# === Simulate orders from buyer to merchant's products ===
statuses = %w[pending shipped processing delivered]
products = shop.products.limit(10)

10.times do
  created_time = Faker::Time.backward(days: 30)
  order = buyer.orders.create!(
    status: statuses.sample,
    total_items: 0,
    total_price: 0,
    created_at: created_time,
    updated_at: created_time
  )

  total_items = 0
  total_price = 0

  rand(2..4).times do
    product = products.sample
    quantity = rand(1..3)
    price = product.price

    order.order_items.create!(
      product: product,
      quantity: quantity,
      price: price
    )

    total_items += quantity
    total_price += quantity * price
  end

  order.update!(total_items: total_items, total_price: total_price)
end

puts "✅ Seeded 3 orders for #{buyer.email} to #{merchant.email}"
