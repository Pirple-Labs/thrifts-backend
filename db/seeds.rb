# === Seed categories ===
category_names = [
  "Women’s Clothing",
  "Men’s Clothing",
  "Kids & Babywear",
  "Footwear",
  "Bags & Accessories",
  "Home & Kitchen",
  "Electronics & Gadgets",
  "Books & Media",
  "Beauty & Personal Care",
  "Event & Vintage Wear"
]

new_categories = []

category_names.each do |name|
  category = Category.find_or_create_by(name: name)
  new_categories << category unless category.nil?
end

puts "✅ Verified/Seeded #{new_categories.size} unique categories."
