# app/services/personalization/playbook_manager.rb
# frozen_string_literal: true

module Personalization
  class PlaybookManager
    include ActiveSupport::Configurable
    
    # Configuration
    config_accessor :refresh_interval_hours, :max_concurrent_generations, :cleanup_after_days
    
    # Default configuration
    configure do |config|
      config.refresh_interval_hours = 48
      config.max_concurrent_generations = 5
      config.cleanup_after_days = 7
    end
    
    def self.refresh_expired_playbooks
      new.refresh_expired_playbooks
    end
    
    def self.cleanup_old_playbooks
      new.cleanup_old_playbooks
    end
    
    def self.generate_playbook_for_user(user_id, page)
      new.generate_playbook_for_user(user_id, page)
    end
    
    def self.health_check
      new.health_check
    end
    
    def refresh_expired_playbooks
      Rails.logger.info "Starting playbook refresh cycle"
      
      # Find expired playbooks
      expired_playbooks = find_expired_playbooks
      Rails.logger.info "Found #{expired_playbooks.count} expired playbooks"
      
      # Group by user and page to avoid duplicates
      grouped_playbooks = group_playbooks_for_refresh(expired_playbooks)
      
      # Generate new playbooks
      generated_count = 0
      grouped_playbooks.each do |(user_id, page), playbooks|
        break if generated_count >= max_concurrent_generations
        
        begin
          generate_new_playbook(user_id, page)
          generated_count += 1
        rescue => e
          Rails.logger.error "Failed to generate playbook for user #{user_id}, page #{page}: #{e.message}"
        end
      end
      
      Rails.logger.info "Generated #{generated_count} new playbooks"
      generated_count
    end
    
    def cleanup_old_playbooks
      Rails.logger.info "Starting playbook cleanup"
      
      # Delete playbooks older than cleanup_after_days
      cutoff_date = cleanup_after_days.days.ago
      deleted_count = Playbook.where('generated_at < ?', cutoff_date).delete_all
      
      Rails.logger.info "Deleted #{deleted_count} old playbooks"
      deleted_count
    end
    
    def generate_playbook_for_user(user_id, page)
      Rails.logger.info "Generating playbook for user #{user_id}, page #{page}"
      
      # Check if user already has an active playbook
      existing_playbook = Playbook.find_active_for_user_and_page(user_id, page)
      if existing_playbook
        Rails.logger.info "User #{user_id} already has active playbook for #{page}"
        return existing_playbook
      end
      
      # Generate new playbook
      generate_new_playbook(user_id, page)
    end
    
    private
    
    def find_expired_playbooks
      Playbook.where('generated_at < ?', refresh_interval_hours.hours.ago)
              .where(ai_generated: true)
              .order(:generated_at)
    end
    
    def group_playbooks_for_refresh(expired_playbooks)
      expired_playbooks.group_by { |pb| [pb.user_id, pb.page] }
    end
    
    def generate_new_playbook(user_id, page)
      # Build user context
      user_context = build_user_context(user_id, page)
      
      # Generate playbook
      playbook = Personalization::PlaybookGenerator.generate_for_user(user_id, page, user_context)
      
      Rails.logger.info "Generated playbook #{playbook.playbook_id} for user #{user_id}, page #{page}"
      playbook
    end
    
    def build_user_context(user_id, page)
      user = User.find_by(id: user_id)
      return {} unless user
      
      {
        user_id: user_id,
        region: 'ke', # Default region
        page: page,
        user_characteristics: extract_user_characteristics(user)
      }
    end
    
    def extract_user_characteristics(user)
      {
        registration_date: user.created_at,
        total_orders: user.orders.count,
        total_wishlist_items: user.wishlist_items.count,
        preferred_categories: extract_preferred_categories(user),
        preferred_brands: extract_preferred_brands(user),
        avg_order_value: calculate_avg_order_value(user)
      }
    end
    
    def extract_preferred_categories(user)
      # Extract user's preferred categories from orders and wishlist
      category_ids = []
      
      # From orders
      category_ids.concat(
        user.orders.joins(:products).pluck('products.category_id').compact
      )
      
      # From wishlist
      category_ids.concat(
        user.wishlist_items.joins(:product).pluck('products.category_id').compact
      )
      
      # Get top categories
      category_counts = category_ids.tally
      top_categories = category_counts.sort_by { |_, count| -count }.first(5).map(&:first)
      
      Category.where(id: top_categories).pluck(:name)
    end
    
    def extract_preferred_brands(user)
      # Extract user's preferred brands from orders and wishlist
      brand_ids = []
      
      # From orders
      brand_ids.concat(
        user.orders.joins(:products).pluck('products.brand_id').compact
      )
      
      # From wishlist
      brand_ids.concat(
        user.wishlist_items.joins(:product).pluck('products.brand_id').compact
      )
      
      # Get top brands
      brand_counts = brand_ids.tally
      top_brands = brand_counts.sort_by { |_, count| -count }.first(5).map(&:first)
      
      Brand.where(id: top_brands).pluck(:name)
    end
    
    def calculate_avg_order_value(user)
      orders = user.orders.where.not(total_amount: nil)
      return 0 if orders.empty?
      
      orders.average(:total_amount).to_f
    end
    
    def health_check
      Rails.logger.info "Running playbook system health check"
      
      # Check active playbooks count
      active_count = Playbook.active.count
      Rails.logger.info "Active playbooks: #{active_count}"
      
      # Check expired playbooks count
      expired_count = find_expired_playbooks.count
      Rails.logger.info "Expired playbooks: #{expired_count}"
      
      # Check AI service connectivity
      ai_service_healthy = check_ai_service_health
      Rails.logger.info "AI service health: #{ai_service_healthy ? 'healthy' : 'unhealthy'}"
      
      # Store health metrics
      store_health_metrics(active_count, expired_count, ai_service_healthy)
      
      {
        active_playbooks: active_count,
        expired_playbooks: expired_count,
        ai_service_healthy: ai_service_healthy,
        timestamp: Time.current.iso8601
      }
    end
    
    def check_ai_service_health
      begin
        response = HTTParty.get(
          "#{Personalization::PlaybookGenerator.ai_service_url}/health",
          timeout: 5
        )
        response.success?
      rescue => e
        Rails.logger.warn "AI service health check failed: #{e.message}"
        false
      end
    end
    
    def store_health_metrics(active_count, expired_count, ai_service_healthy)
      Rails.cache.write(
        "playbook_health_metrics:#{Time.current.strftime('%Y-%m-%d-%H')}",
        {
          active_playbooks: active_count,
          expired_playbooks: expired_count,
          ai_service_healthy: ai_service_healthy,
          timestamp: Time.current.iso8601
        },
        expires_in: 24.hours
      )
    rescue => e
      Rails.logger.warn "Failed to store health metrics: #{e.message}"
    end
  end
end
