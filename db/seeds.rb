require 'faker'

# Clear existing data
Product.destroy_all

# Predefined options
conditions       = ["New", "Like New", "Used", "Refurbished"]
brands           = ["Nike", "Adidas", "Zara", "Samsung", "Apple", "Sony", "H&M", "Gucci", "Dell", "Canon"]
payment_methods  = ["M-Pesa", "Credit Card", "Cash on Delivery", "PayPal"]
delivery_modes   = ["Pick-up", "Home Delivery", "Courier Service"]

# Create 200 products
200.times do
  Product.create!(
    name:            "#{Faker::Commerce.department(max: 1, fixed_amount: true)} #{Faker::Commerce.material}", 
    store_logo:      "https://picsum.photos/seed/#{rand(1000)}/100/100",
    product_image:   "https://picsum.photos/seed/#{rand(1000..9999)}/300/300",
    price:           Faker::Commerce.price(range: 10.0..100.0, as_string: true),
    description:     Faker::Marketing.buzzwords,
    condition:       conditions.sample,
    brand:           brands.sample,
    payment:         payment_methods.sample,
    mode_of_delivery: delivery_modes.sample
  )
end

puts "✅ Seeded #{Product.count} products with full info!"
