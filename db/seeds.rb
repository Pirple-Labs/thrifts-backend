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

p# Grab user and some products
user = User.find_by(email: "jessemutua76@gmail.com")
products = Product.limit(10) # You can adjust this number

# Seed recommended products for the user
products.each_with_index do |product, index|
  RecommendedProduct.find_or_create_by!(
    user: user,
    product: product
  ) do |rec|
    rec.rank = index + 1
    rec.reason = Faker::Marketing.buzzwords
  end
end

puts "✅ Seeded #{products.size} recommended products for #{user.email}"
# Seed orders and order items
statuses = ["pending", "shipped", "processing", "delivered"]
user = User.find_by(email: "jessemutua76@gmail.com")
products = Product.all.sample(10)

3.times do |i|
  status = statuses.sample
  created_time = Faker::Time.backward(days: 30)

  # Create the order
  order = user.orders.create!(
    status: status,
    total_items: 0, # Will be updated below
    total_price: 0,
    created_at: created_time,
    updated_at: created_time
  )

  total_price = 0
  total_items = 0

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
    total_price += price * quantity
  end

  order.update!(total_items: total_items, total_price: total_price)
end

puts "✅ Seeded 3 orders with items for #{user.email}"
