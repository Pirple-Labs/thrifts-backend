require 'faker'

# Create dummy user and shop
user = User.find_or_create_by!(email: "testexample1@gmail.com") do |u|
  u.password = "password123"
end

shop = user.shops.find_or_create_by!(
  name: "Sample Shop",
  phone: "0712345678",
  location: "Nairobi",
  store_logo_url: "https://loremflickr.com/200/200/shop_logo?lock=1",
  description: "A demo shop with sample products",
  pickup_agent: "Yes",
  agreed: true
)

# Optionally seed a few categories if not present
category_names = ["Clothing", "Electronics", "Books", "Shoes", "Home Decor"]
categories = category_names.map do |name|
  Category.find_or_create_by!(name: name)
end

# Seed 20 products
20.times do |i|
  images = [
    "https://loremflickr.com/300/300/product?lock=#{i}",
    "https://loremflickr.com/300/300/item?lock=#{i + 100}",
    "https://loremflickr.com/300/300/shop?lock=#{i + 200}"
  ]

  Product.create!(
    name: Faker::Commerce.product_name,
    main_image: images.first,
    supplementary_images: images.drop(1),
    price: Faker::Commerce.price(range: 1000.0..15000.0),
    description: Faker::Lorem.sentence(word_count: 12),
    views: rand(10..1000),
    shop: shop,
    category: categories.sample
  )
end

puts "✅ Seeded #{Product.count} products linked to '#{shop.name}'"
