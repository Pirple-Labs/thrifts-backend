# app/controllers/api/checkout_controller.rb
# frozen_string_literal: true

module Api
  class CheckoutController < Api::BaseController
    before_action :authenticate_user!
    
    # GET /api/checkout/layout?user_id=U123
    def layout
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      
      # Build user context
      user_context = build_user_context
      
      # Execute playbook
      playbook_response = Personalization::PlaybookExecutor.execute_for_user(
        current_user.id,
        'checkout',
        user_context
      )
      
      # Get cart items
      cart_items = get_cart_items
      
      # Process modules for checkout
      processed_modules = process_checkout_modules(playbook_response[:modules])
      
      # Build final response
      response = {
        layout: {
          order_summary: cart_items,
          modules: processed_modules
        },
        metadata: playbook_response[:metadata].merge(
          processing_time_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        )
      }
      
      render json: response
      
    rescue => e
      Rails.logger.error "Checkout layout generation failed: #{e.message}"
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
    
    def get_cart_items
      cart_items = current_user.cart_items
                              .includes(:product)
                              .order(created_at: :desc)
      
      cart_items.map do |cart_item|
        product = cart_item.product
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
          quantity: cart_item.quantity
        }
      end
    end
    
    def process_checkout_modules(modules)
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
      when /addon/
        'size-agnostic complements under $20'
      when /bundle/
        'cart overlaps bundle composition'
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
          order_summary: get_cart_items,
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

