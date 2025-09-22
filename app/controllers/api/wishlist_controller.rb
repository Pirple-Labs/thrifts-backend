# app/controllers/api/wishlist_controller.rb
# frozen_string_literal: true

module Api
  class WishlistController < Api::BaseController
    before_action :authenticate_user!
    
    # GET /api/wishlist/layout?user_id=U123
    def layout
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      
      # Build user context
      user_context = build_user_context
      
      # Execute playbook
      playbook_response = Personalization::PlaybookExecutor.execute_for_user(
        current_user.id,
        'wishlist',
        user_context
      )
      
      # Get saved items
      saved_items = get_saved_items
      
      # Process modules for wishlist
      processed_modules = process_wishlist_modules(playbook_response[:modules])
      
      # Build final response
      response = {
        layout: {
          saved_items_grid: saved_items,
          modules: processed_modules
        },
        metadata: playbook_response[:metadata].merge(
          processing_time_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        )
      }
      
      render json: response
      
    rescue => e
      Rails.logger.error "Wishlist layout generation failed: #{e.message}"
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
    
    def get_saved_items
      wishlist_items = current_user.wishlist_items
                                  .includes(:product)
                                  .order(created_at: :desc)
                                  .limit(50)
      
      wishlist_items.map do |wishlist_item|
        product = wishlist_item.product
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
          category: product.category&.name,
          saved_at: wishlist_item.created_at.iso8601,
          price_drop: check_price_drop(product),
          back_in_stock: check_back_in_stock(product)
        }
      end
    end
    
    def process_wishlist_modules(modules)
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
      when /price_drop/
        '10%+ price drop'
      when /back_in_stock/
        'recently restocked'
      when /complete/
        'high attach-rate complements'
      when /similar/
        'saved item OOS'
      else
        'personalized recommendation'
      end
    end
    
    def check_price_drop(product)
      # Check if product has had a price drop in the last 7 days
      # This would be implemented based on your price history data
      false
    end
    
    def check_back_in_stock(product)
      # Check if product was OOS and recently restocked
      # This would be implemented based on your inventory data
      false
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
          saved_items_grid: get_saved_items,
          modules: []
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

