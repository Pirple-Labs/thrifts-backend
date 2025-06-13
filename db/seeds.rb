require 'faker'

# Create one dummy user and shop for association
user = User.create!(email: "testexample@gmail.com", password: "password123")
shop = user.shops.create!(
  name: "Sample Shop",
  phone: "0712345678",
  location: "Nairobi",
  store_logo_url: "https://picsum.photos/seed/shop/200/200", # corrected field
  description: "A demo shop",
  pickup_agent: true,
  agreed: true
)

# Seed 10 products
10.times do
  image_urls = Array.new(3) { "https://picsum.photos/seed/#{rand(1000..9999)}/300/300" }

  Product.create!(
    name: Faker::Commerce.product_name,
    main_image: image_urls.first,                # main image
    supplementary_images: image_urls.drop(1),    # additional images
    price: Faker::Commerce.price(range: 1000.0..15000.0),
    description: Faker::Lorem.paragraph(sentence_count: 2),
    views: rand(1..500),
    shop: shop
  )
end

puts "✅ Seeded #{Product.count} products linked to '#{shop.name}'"
