require 'faker'

Product.destroy_all # Clear existing data

10.times do
  Product.create!(
    name: "#{Faker::Commerce.department(max: 1, fixed_amount: true)} #{Faker::Commerce.material}", 
    store_logo: "https://picsum.photos/seed/#{rand(1000)}/100/100",
    product_image: "https://picsum.photos/seed/#{rand(1000)}/300/300",
    price: Faker::Commerce.price(range: 10.0..100.0, as_string: true),
    description: Faker::Marketing.buzzwords
  )
end

puts "✅ Seeded #{Product.count} clothing products!"
