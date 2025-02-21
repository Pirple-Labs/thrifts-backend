# db/seeds.rb

require 'faker'

Product.destroy_all # Clear existing data

10.times do
  Product.create!(
    name: Faker::Commerce.department(max: 1, fixed_amount: true) + " " + Faker::Commerce.material, 
    store_logo: Faker::LoremFlickr.image(size: "100x100", search_terms: ['clothing', 'brand']),
    product_image: Faker::LoremFlickr.image(size: "300x300", search_terms: ['fashion', 'clothes']),
    price: Faker::Commerce.price(range: 10.0..100.0, as_string: true),
    description: Faker::Marketing.buzzwords
  )
end

puts "✅ Seeded #{Product.count} clothing products!"
