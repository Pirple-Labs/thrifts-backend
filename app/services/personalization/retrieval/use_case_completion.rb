# frozen_string_literal: true

module Personalization
  module Retrieval
    class UseCaseCompletion
      def self.run(section_config, snapshot, profile, session_embed_summary)
        new(section_config, snapshot, profile, session_embed_summary).run
      end

      def initialize(section_config, snapshot, profile, session_embed_summary)
        @section_config = section_config
        @snapshot = snapshot
        @profile = profile
        @session_embed_summary = session_embed_summary
        @count = section_config[:count] || 6
        @filters = section_config[:filters] || {}
        @hints = section_config[:hints] || {}
      end

      def run
        # Get current products (from cart or recent activity)
        current_products = get_current_products
        
        # Determine use case template
        template = determine_use_case_template(current_products)
        return [] unless template

        # Calculate current coverage
        coverage = calculate_coverage(current_products, template)
        
        # Find missing slots
        missing_slots = find_missing_slots(coverage, template)
        
        # Get products for missing slots
        completion_products = get_completion_products(missing_slots, template)

        # Add use case metadata
        add_use_case_metadata(completion_products, template, coverage)
      end

      private

      def get_current_products
        case @snapshot[:page]
        when 'cart', 'checkout'
          # In real implementation, would get from cart service
          Product.limit(3)
        when 'pdp'
          # Use the current product as seed
          if @snapshot[:pid]
            product = Product.find_by(id: @snapshot[:pid])
            return [product] if product
          end
          Product.limit(1)
        else
          # For home/search, use recent products
          Product.limit(2)
        end
      end

      def determine_use_case_template(current_products)
        return nil if current_products.empty?

        # Try to match based on template hint
        if @hints['template_hint']
          template = UsecaseTemplate.find_by(template_id: @hints['template_hint'])
          return template if template
        end

        # Try to infer from current products
        primary_product = current_products.first
        case primary_product.category
        when 'electronics'
          if primary_product.name.downcase.include?('laptop')
            UsecaseTemplate.find_by(template_id: 'laptop_setup')
          elsif primary_product.name.downcase.include?('gaming')
            UsecaseTemplate.find_by(template_id: 'gaming_setup')
          else
            UsecaseTemplate.find_by(template_id: 'electronics_setup')
          end
        when 'furniture'
          if primary_product.name.downcase.include?('gaming')
            UsecaseTemplate.find_by(template_id: 'gaming_setup')
          else
            UsecaseTemplate.find_by(template_id: 'home_office')
          end
        else
          UsecaseTemplate.find_by(template_id: 'general_setup')
        end
      end

      def calculate_coverage(current_products, template)
        return { completed: 0, total: 0, missing_slots: [] } unless template

        slots = template.slots || []
        completed_slots = []

        current_products.each do |product|
          slot = map_product_to_slot(product, slots)
          completed_slots << slot if slot
        end

        {
          completed: completed_slots.uniq.length,
          total: slots.length,
          missing_slots: slots - completed_slots.uniq,
          completed_slots: completed_slots.uniq
        }
      end

      def map_product_to_slot(product, slots)
        # Map product to template slot based on category and attributes
        case product.category
        when 'electronics'
          case product.name.downcase
          when /stand/ then 'stand'
          when /mouse/ then 'mouse'
          when /bag/ then 'bag'
          when /hub/ then 'hub'
          when /monitor/ then 'monitor'
          when /lamp/ then 'lamp'
          when /lighting/ then 'lighting'
          when /charger/ then 'charger'
          when /case/ then 'case'
          when /protector/ then 'protector'
          when /mount/ then 'mount'
          end
        when 'furniture'
          case product.name.downcase
          when /desk/ then 'desk'
          when /chair/ then 'chair'
          when /lamp/ then 'lamp'
          when /organizer/ then 'organizer'
          when /stand/ then 'stand'
          end
        when 'bags'
          'bag'
        end
      end

      def find_missing_slots(coverage, template)
        return [] unless template

        threshold = template.rules['completion_threshold'] || 0.8
        current_completion = coverage[:completed].to_f / coverage[:total]
        
        if current_completion < threshold
          coverage[:missing_slots]
        else
          []
        end
      end

      def get_completion_products(missing_slots, template)
        return [] if missing_slots.empty?

        products = []
        
        missing_slots.each do |slot|
          # Find products for this slot
          slot_products = find_products_for_slot(slot, template)
          products += slot_products.first(2) # Max 2 per slot
        end

        # Apply guardrails
        guardrails_result = Personalization::Guardrails.apply(
          products.map { |p| { id: p.id, score: 0.8 } },
          {
            region: @snapshot[:region],
            pickup_only: @snapshot[:pickup_only],
            price_band: @profile[:price_band],
            max_merchants: 2
          }
        )

        # Add coordination metadata
        products = guardrails_result[:products] || []
        add_coordination_metadata(products, missing_slots)
      end

      def find_products_for_slot(slot, template)
        # Find products that match the slot requirements
        case slot
        when 'stand'
          Product.joins(:shop)
                 .where(category: 'electronics')
                 .where("products.name ILIKE ?", "%stand%")
                 .where("products.stock > 0")
                 .where("products.moderation_status = ?", "approved")
        when 'mouse'
          Product.joins(:shop)
                 .where(category: 'electronics')
                 .where("products.name ILIKE ?", "%mouse%")
                 .where("products.stock > 0")
                 .where("products.moderation_status = ?", "approved")
        when 'bag'
          Product.joins(:shop)
                 .where(category: 'bags')
                 .where("products.stock > 0")
                 .where("products.moderation_status = ?", "approved")
        when 'desk'
          Product.joins(:shop)
                 .where(category: 'furniture')
                 .where("products.name ILIKE ?", "%desk%")
                 .where("products.stock > 0")
                 .where("products.moderation_status = ?", "approved")
        when 'chair'
          Product.joins(:shop)
                 .where(category: 'furniture')
                 .where("products.name ILIKE ?", "%chair%")
                 .where("products.stock > 0")
                 .where("products.moderation_status = ?", "approved")
        else
          # Generic fallback
          Product.joins(:shop)
                 .where("products.stock > 0")
                 .where("products.moderation_status = ?", "approved")
                 .limit(5)
        end
      end

      def add_coordination_metadata(products, missing_slots)
        products.map do |product_data|
          product = product_data.is_a?(Hash) ? Product.find(product_data[:id]) : product_data
          
          {
            id: product.id,
            score: product_data[:score] || 0.8,
            role: 'bundle_component',
            bundle_slot: determine_slot_for_product(product, missing_slots)
          }
        end
      end

      def determine_slot_for_product(product, missing_slots)
        # Determine which slot this product fills
        case product.category
        when 'electronics'
          case product.name.downcase
          when /stand/ then 'stand'
          when /mouse/ then 'mouse'
          when /hub/ then 'hub'
          when /monitor/ then 'monitor'
          when /lamp/ then 'lamp'
          when /lighting/ then 'lighting'
          when /charger/ then 'charger'
          when /case/ then 'case'
          when /protector/ then 'protector'
          when /mount/ then 'mount'
          end
        when 'furniture'
          case product.name.downcase
          when /desk/ then 'desk'
          when /chair/ then 'chair'
          when /lamp/ then 'lamp'
          when /organizer/ then 'organizer'
          when /stand/ then 'stand'
          end
        when 'bags'
          'bag'
        end
      end

      def add_use_case_metadata(products, template, coverage)
        {
          products: products,
          use_case: {
            template_id: template&.template_id,
            coverage: {
              completed: coverage[:completed],
              total: coverage[:total],
              missing_slots: coverage[:missing_slots]
            }
          }
        }
      end
    end
  end
end
