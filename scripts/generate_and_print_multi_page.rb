# frozen_string_literal: true

require 'json'

user = User.first || User.create!(email: 'demo_user@example.com', password: 'Password123!')
pages = %w[home pdp wishlist checkout profile]

# Clear today's playbooks for a clean run
deleted = Playbook.where(user_id: user.id, page: pages, generated_at: (Time.current.beginning_of_day..Time.current.end_of_day)).delete_all
puts({ deleted: deleted }.to_json)

# Generate multi-page plan in one operator call
result = Personalization::PlaybookGenerator.generate_for_user_multi_page(user.id, pages, { region: 'ke' })
puts(result.keys.to_json)

# Print stored content for each page
result.each do |page, pb|
  puts({ page: page, playbook_id: pb.playbook_id, ai_generated: pb.ai_generated }.to_json)
  puts JSON.pretty_generate(pb.content)
end





