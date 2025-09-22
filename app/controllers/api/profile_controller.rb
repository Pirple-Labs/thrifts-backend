# app/controllers/api/profile_controller.rb
# frozen_string_literal: true

module Api
  class ProfileController < Api::BaseController
    before_action :authenticate_user!
    
    # GET /api/profile/top-picks?user_id=U123
    def top_picks
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      
      # Build user context
      user_context = build_user_context
      
      # Execute playbook
      playbook_response = Personalization::PlaybookExecutor.execute_for_user(
        current_user.id,
        'profile',
        user_context
      )
      
      # Process modules for profile
      processed_modules = process_profile_modules(playbook_response[:modules])
      
      # Build final response
      response = {
        layout: {
          modules: processed_modules
        },
        metadata: playbook_response[:metadata].merge(
          processing_time_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        )
      }
      
      render json: response
      
    rescue => e
      Rails.logger.error "Profile top picks generation failed: #{e.message}"
      render_fallback_response
    end
    
    private
    
    def build_user_context
      {
        user_id: current_user.id,
        session_id: session[:session_id] || "anon_#{SecureRandom.hex(8)}",
        region: params[:region] || 'ke',
        pickup_only: ActiveModel::Type::Boolean.new.cast(params[:pickup_only])
      }
    end
    
    def process_profile_modules(modules)
      modules.map do |module_data|
        {
          slot: module_data[:placement],
          module: module_data[:id],
          items: build_lite_products(module_data[:items]),
          reason: generate_module_reason(module_data),
          metadata: module_data[:metadata]
        }
      end
    end
    
    def generate_module_reason(module_data)
      case module_data[:id]
      when /picks_today/
        'daily taste refresh'
      when /new_from_brands/
        'loyalty brand updates'
      when /continue_browsing/
        'recent user interactions'
      when /exploration/
        'reduce personalization bubble'
      else
        'personalized recommendation'
      end
    end
    
    def build_lite_products(product_ids)
      return [] unless product_ids&.any?
      
      products = Product.where(id: product_ids)
                       .includes(:shop, :brand, :category)
                       .limit(50)
      
      products.map do |product|
        {
          id: product.id,
          name: product.name,
          price: product.price,
          image_url: product.image_url,
          shop: {
            id: product.shop.id,
            name: product.shop.name
          },
          brand: product.brand&.name,
          category: product.category&.name
        }
      end
    end
    
    def render_fallback_response
      render json: {
        layout: {
          modules: [
            {
              slot: 'top',
              module: 'your_picks_today',
              items: [],
              reason: 'fallback',
              metadata: { fallback: true }
            }
          ]
        },
        metadata: {
          ai_generated: false,
          fallback: true,
          processing_time_ms: 0
        }
      }
    end
  end
end

