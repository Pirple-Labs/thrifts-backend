# frozen_string_literal: true

require 'json'

user = User.first || User.create!(email: 'demo_user@example.com', password: 'Password123!')
pages = %w[home pdp wishlist checkout profile]

pages.each do |page|
  existing = Playbook.find_active_for_user_and_page(user.id, page)
  pb = existing || Personalization::PlaybookGenerator.generate_for_user(user.id, page, { region: 'ke' })
  puts("===== PAGE: #{page} =====")
  puts({ playbook_id: pb.playbook_id, page: pb.page, ai_generated: pb.ai_generated, generated_at: pb.generated_at.iso8601, valid_for_hours: pb.valid_for_hours }.to_json)
  puts(JSON.pretty_generate(pb.content))
  puts
end


