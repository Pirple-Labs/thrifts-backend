# app/jobs/playbook_refresh_job.rb
# frozen_string_literal: true

class PlaybookRefreshJob < ApplicationJob
  queue_as :default
  
  def perform
    Rails.logger.info "Starting PlaybookRefreshJob"
    
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    
    begin
      # Refresh expired playbooks
      refreshed_count = Personalization::PlaybookManager.refresh_expired_playbooks
      
      # Cleanup old playbooks
      cleaned_count = Personalization::PlaybookManager.cleanup_old_playbooks
      
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      
      Rails.logger.info "PlaybookRefreshJob completed: #{refreshed_count} refreshed, #{cleaned_count} cleaned, #{duration.round(2)}s"
      
      # Track metrics
      track_refresh_metrics(refreshed_count, cleaned_count, duration)
      
    rescue => e
      Rails.logger.error "PlaybookRefreshJob failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Track error metrics
      track_error_metrics(e)
    end
  end
  
  private
  
  def track_refresh_metrics(refreshed_count, cleaned_count, duration)
    # Track metrics for monitoring
    Rails.cache.write(
      "playbook_refresh_metrics:#{Date.current}",
      {
        refreshed_count: refreshed_count,
        cleaned_count: cleaned_count,
        duration_seconds: duration,
        timestamp: Time.current.iso8601
      },
      expires_in: 7.days
    )
  rescue => e
    Rails.logger.warn "Failed to track refresh metrics: #{e.message}"
  end
  
  def track_error_metrics(error)
    # Track error metrics for monitoring
    Rails.cache.write(
      "playbook_refresh_error:#{Date.current}",
      {
        error_message: error.message,
        error_class: error.class.name,
        timestamp: Time.current.iso8601
      },
      expires_in: 7.days
    )
  rescue => e
    Rails.logger.warn "Failed to track error metrics: #{e.message}"
  end
end

