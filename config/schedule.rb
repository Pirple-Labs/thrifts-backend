# config/schedule.rb
# frozen_string_literal: true

# Playbook refresh cycle - every 6 hours to catch expired playbooks
every 6.hours do
  runner "PlaybookRefreshJob.perform_later"
end

# Playbook cleanup - daily at 2 AM
every 1.day, at: '2:00 am' do
  runner "Personalization::PlaybookManager.cleanup_old_playbooks"
end

# Health check for playbook system - every hour
every 1.hour do
  runner "Personalization::PlaybookManager.health_check"
end

