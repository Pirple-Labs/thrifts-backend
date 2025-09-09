# frozen_string_literal: true

module Personalization
  module Retrieval
    class Complements
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
        # Get seed products (from PDP or cart context)
        seed_products = get_seed_products
        
        return [] if seed_products.empty?

        # Resolve hints if provided
        resolved_hints = resolve_hints if @hints.any?

        # Find complementary products using DRG
        candidates = find_complementary_products(seed_products, resolved_hints)

        # Apply guardrails
        guardrails_result = Personalization::Guardrails.apply(
          candidates,
          {
            region: @snapshot[:region],
            pickup_only: @snapshot[:pickup_only],
            price_band: @profile[:price_band],
            max_merchants: 2
          }
        )

        # If underfilled, backfill with trending
        products = guardrails_result[:products] || []
        if products.length < @count
          backfill_candidates = Personalization::Retrieval::Trending.run(
            @filters,
            { count: @count - products.length },
            {
              snapshot: @snapshot,
              profile: @profile,
              session_embed_summary: @session_embed_summary
            }
          )
          
          products += backfill_candidates
        end

        # Add coordination metadata
        add_coordination_metadata(products, seed_products, resolved_hints)
      end

      private

      def get_seed_products
        # For PDP, use the current product
        if @snapshot[:page] == 'pdp' && @snapshot[:pid]
          product = Product.find_by(id: @snapshot[:pid])
          return [product] if product
        end

        # For cart/checkout, use cart items (simplified for demo)
        if ['cart', 'checkout'].include?(@snapshot[:page])
          # In real implementation, would get from cart service
          return Product.limit(3)
        end

        # For home/search, use recent products
        Product.limit(1)
      end

      def resolve_hints
        return [] unless @hints['product_types']&.any?

        NameHintResolver.resolve_hints(
          @hints,
          request_id: SecureRandom.uuid,
          page: @snapshot[:page],
          section_id: @section_config[:id]
        )
      end

      def find_complementary_products(seed_products, resolved_hints)
        candidates = []

        seed_products.each do |seed|
          # Query product relations for complements
          relations = ProductRelation.where(
            seed_id: seed.id,
            rel_type: 'complement',
            region: @snapshot[:region]
          ).order(score: :desc)

          # Apply hint constraints if available
          if resolved_hints.any?
            relations = filter_by_hints(relations, resolved_hints)
          end

          # Apply overrides (boost/block)
          relations = apply_overrides(relations, seed.id)

          # Convert to candidates
          relations.limit(@count * 2).each do |relation|
            candidates << {
              id: relation.cand_id,
              score: relation.score,
              features: relation.features,
              seed_id: seed.id
            }
          end
        end

        # Remove duplicates and sort by score
        candidates.uniq { |c| c[:id] }
                 .sort_by { |c| -c[:score] }
                 .first(@count * 3) # Get more candidates for guardrails
      end

      def filter_by_hints(relations, resolved_hints)
        # Filter relations based on resolved hints
        # This is a simplified implementation
        relations.joins(:cand_product)
                 .where(products: { category: resolved_hints.map { |h| h[:category] }.compact })
      end

      def apply_overrides(relations, seed_id)
        # Apply boost/block overrides
        overrides = ProductRelationOverride.where(seed_id: seed_id)
        
        overrides.each do |override|
          relation = relations.find { |r| r.cand_id == override.cand_id }
          next unless relation

          case override.action
          when 'boost'
            relation.score += override.weight
          when 'block'
            relation.score = 0.0
          end
        end

        relations
      end

      def add_coordination_metadata(products, seed_products, resolved_hints)
        products.map do |product_data|
          product = product_data.is_a?(Hash) ? Product.find(product_data[:id]) : product_data
          
          {
            id: product.id,
            score: product_data[:score] || 0.8,
            role: 'bundle_component',
            bundle_slot: determine_bundle_slot(product, resolved_hints),
            seed_id: product_data[:seed_id]
          }
        end
      end

      def determine_bundle_slot(product, resolved_hints)
        # Determine bundle slot based on product and hints
        case product.category
        when 'electronics'
          case product.name.downcase
          when /stand/ then 'stand'
          when /mouse/ then 'mouse'
          when /bag/ then 'bag'
          when /hub/ then 'hub'
          when /monitor/ then 'monitor'
          else 'accessory'
          end
        when 'furniture'
          case product.name.downcase
          when /desk/ then 'desk'
          when /chair/ then 'chair'
          when /lamp/ then 'lamp'
          else 'furniture'
          end
        else
          'accessory'
        end
      end
    end
  end
end
