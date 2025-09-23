# app/controllers/api/pdp_controller.rb
# frozen_string_literal: true

module Api
  class PdpController < Api::BaseController
    skip_before_action :authenticate_user!, only: [:layout], raise: false
    
    # GET /api/pdp/layout?sku=SKU_123
    def layout
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      
      # Validate required parameters
      unless params[:sku].present?
        render json: { error: "SKU parameter is required" }, status: 400
        return
      end
      
      # Find product
      product = Product.find_by(sku: params[:sku])
      unless product
        render json: { error: "Product not found" }, status: 404
        return
      end
      
      # Build user context
      user_context = build_user_context(product)
      
      # Execute playbook
      playbook_response = Personalization::PlaybookExecutor.execute_for_user(
        current_user&.id,
        'pdp',
        user_context
      )
      
      # Process modules for PDP
      processed_modules = process_pdp_modules(playbook_response[:modules], product)
      
      # Build final response
      response = {
        sku: params[:sku],
        layout: {
          complements_strip: extract_complements_strip(processed_modules),
          similar_grid: extract_similar_grid(processed_modules),
          optional_injection: extract_optional_injection(processed_modules)
        },
        metadata: playbook_response[:metadata].merge(
          processing_time_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        )
      }
      
      render json: response
      
    rescue => e
      Rails.logger.error "PDP layout generation failed: #{e.message}"
      render_fallback_response(product)
    end
    
    private
    
    def build_user_context(product)
      {
        user_id: current_user&.id,
        session_id: session[:session_id] || "anon_#{SecureRandom.hex(8)}",
        product_id: product.id,
        sku: product.sku,
        region: params[:region] || 'ke',
        pickup_only: ActiveModel::Type::Boolean.new.cast(params[:pickup_only])
      }
    end
    
    def process_pdp_modules(modules, product)
      modules.map do |module_data|
        {
          id: module_data[:id],
          type: module_data[:type],
          placement: module_data[:placement],
          items: build_lite_products(module_data[:items]),
          metadata: module_data[:metadata].merge(
            reference_product: {
              id: product.id,
              name: product.name,
              sku: product.sku
            }
          )
        }
      end
    end
    
    def extract_complements_strip(modules)
      complements_module = modules.find { |m| m[:placement] == 'pdp_below_gallery' }
      return nil unless complements_module&.dig(:items)&.any?
      
      {
        module: 'complete_the_look',
        items: complements_module[:items],
        reason: 'attach-rate > 8%',
        metadata: complements_module[:metadata]
      }
    end
    
    def extract_similar_grid(modules)
      similar_module = modules.find { |m| m[:placement] == 'pdp_below_details' }
      injection_module = modules.find { |m| m[:placement] == 'pdp_injection' }
      
      {
        base: {
          module: 'similar_items',
          items: similar_module&.dig(:items) || []
        },
        injection: injection_module ? {
          after_row: 2,
          module: injection_module[:id],
          items: injection_module[:items],
          reason: 'user affinity detected',
          metadata: injection_module[:metadata]
        } : nil
      }
    end
    
    def extract_optional_injection(modules)
      injection_module = modules.find { |m| m[:placement] == 'pdp_injection' }
      return nil unless injection_module
      
      {
        after_row: 2,
        module: injection_module[:id],
        items: injection_module[:items],
        reason: 'high confidence injection',
        metadata: injection_module[:metadata]
      }
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
    
    def render_fallback_response(product)
      render json: {
        sku: params[:sku],
        layout: {
          complements_strip: {
            module: 'complete_the_look',
            items: [],
            reason: 'fallback'
          },
          similar_grid: {
            base: {
              module: 'similar_items',
              items: []
            },
            injection: nil
          },
          optional_injection: nil
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

