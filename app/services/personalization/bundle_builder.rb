# frozen_string_literal: true

module Personalization
  class BundleBuilder
    # Static discount policy (MVP)
    DISCOUNT_POLICY = {
      2 => 0.10,  # 10% for 2 items
      3 => 0.15,  # 15% for 3 items
      4 => 0.20   # 20% for 4+ items
    }.freeze

    def self.build(seed_products:, template_hint: nil, region: 'ke', count: 4)
      new(seed_products, template_hint, region, count).build
    end

    def initialize(seed_products, template_hint, region, count)
      @seed_products = seed_products
      @template_hint = template_hint
      @region = region
      @count = count
    end

    def build
      return nil if @seed_products.empty?

      # Determine template
      template = find_template
      return nil unless template

      # Get bundle products
      bundle_products = select_bundle_products(template)
      return nil if bundle_products.empty?

      # Calculate pricing
      pricing = calculate_pricing(bundle_products)

      # Generate bundle ID
      bundle_id = generate_bundle_id(template, bundle_products)

      {
        bundle_id: bundle_id,
        template_id: template.template_id,
        products: bundle_products,
        pricing: pricing,
        discount_pct: pricing[:discount_pct],
        reason: "Save #{pricing[:discount_pct]}% when you buy these together"
      }
    end

    private

    def find_template
      if @template_hint
        UsecaseTemplate.find_by(template_id: @template_hint)
      else
        # Infer from seed products
        infer_template_from_products
      end
    end

    def infer_template_from_products
      primary_product = @seed_products.first
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

    def select_bundle_products(template)
      slots = template.slots || []
      bundle_products = []
      used_merchants = Set.new

      # Greedy selection per slot
      slots.each do |slot|
        next if bundle_products.length >= @count

        # Find best product for this slot
        slot_product = find_best_product_for_slot(slot, used_merchants, bundle_products)
        next unless slot_product

        bundle_products << {
          id: slot_product.id,
          role: 'bundle_component',
          bundle_slot: slot,
          score: 0.9
        }

        # Track merchant for diversity
        used_merchants.add(slot_product.shop_id)
      end

      # If we need more products, fill with complements
      if bundle_products.length < @count
        complement_products = find_complement_products(bundle_products, used_merchants)
        bundle_products += complement_products.first(@count - bundle_products.length)
      end

      bundle_products
    end

    def find_best_product_for_slot(slot, used_merchants, existing_products)
      # Find products that match the slot
      candidates = case slot
      when 'stand'
        Product.joins(:shop)
               .where(category: 'electronics')
               .where("products.name ILIKE ?", "%stand%")
               .where("products.stock > 0")
               .where("products.moderation_status = ?", "approved")
               .where(shops: { location: @region })
      when 'mouse'
        Product.joins(:shop)
               .where(category: 'electronics')
               .where("products.name ILIKE ?", "%mouse%")
               .where("products.stock > 0")
               .where("products.moderation_status = ?", "approved")
               .where(shops: { location: @region })
      when 'bag'
        Product.joins(:shop)
               .where(category: 'bags')
               .where("products.stock > 0")
               .where("products.moderation_status = ?", "approved")
               .where(shops: { location: @region })
      when 'desk'
        Product.joins(:shop)
               .where(category: 'furniture')
               .where("products.name ILIKE ?", "%desk%")
               .where("products.stock > 0")
               .where("products.moderation_status = ?", "approved")
               .where(shops: { location: @region })
      when 'chair'
        Product.joins(:shop)
               .where(category: 'furniture')
               .where("products.name ILIKE ?", "%chair%")
               .where("products.stock > 0")
               .where("products.moderation_status = ?", "approved")
               .where(shops: { location: @region })
      else
        Product.joins(:shop)
               .where("products.stock > 0")
               .where("products.moderation_status = ?", "approved")
               .where(shops: { location: @region })
               .limit(10)
      end

      # Apply merchant diversity constraint
      candidates = candidates.where.not(shop_id: used_merchants.to_a) if used_merchants.any?

      # Apply price band constraint
      candidates = apply_price_band_filter(candidates)

      # Return best candidate
      candidates.order(:price).first
    end

    def find_complement_products(existing_products, used_merchants)
      return [] if existing_products.empty?

      # Use DRG to find complements
      seed_ids = existing_products.map { |p| p[:id] }
      
      relations = ProductRelation.where(
        seed_id: seed_ids,
        rel_type: 'complement',
        region: @region
      ).order(score: :desc)

      # Apply merchant diversity
      relations = relations.joins(:cand_product)
                          .where.not(products: { shop_id: used_merchants.to_a }) if used_merchants.any?

      # Apply price band
      relations = apply_price_band_filter(relations.joins(:cand_product))

      # Convert to bundle format
      relations.limit(5).map do |relation|
        {
          id: relation.cand_id,
          role: 'bundle_component',
          bundle_slot: 'accessory',
          score: relation.score
        }
      end
    end

    def apply_price_band_filter(query)
      # Apply price band filter based on seed products
      return query if @seed_products.empty?

      avg_price = @seed_products.sum(&:price) / @seed_products.length
      price_range = case avg_price
      when 0..100
        (0..200) # Low price band
      when 100..500
        (100..1000) # Mid price band
      else
        (500..Float::INFINITY) # High price band
      end

      query.where(products: { price: price_range })
    end

    def calculate_pricing(bundle_products)
      return { price_before_cents: 0, price_after_cents: 0, discount_pct: 0 } if bundle_products.empty?

      # Get actual products
      product_ids = bundle_products.map { |p| p[:id] }
      products = Product.where(id: product_ids)

      # Calculate total price
      total_price_cents = products.sum(&:price) * 100

      # Determine discount
      item_count = bundle_products.length
      discount_pct = DISCOUNT_POLICY[item_count] || DISCOUNT_POLICY[4]

      # Calculate final price
      discount_amount_cents = (total_price_cents * discount_pct).round
      final_price_cents = total_price_cents - discount_amount_cents

      {
        price_before_cents: total_price_cents,
        price_after_cents: final_price_cents,
        discount_pct: (discount_pct * 100).round,
        savings_cents: discount_amount_cents
      }
    end

    def generate_bundle_id(template, bundle_products)
      # Generate deterministic bundle ID
      seed_signature = @seed_products.map(&:id).sort.join(',')
      product_signature = bundle_products.map { |p| p[:id] }.sort.join(',')
      timestamp_bucket = Time.current.strftime('%Y%m%d')
      
      hash_input = "#{template.template_id}:#{seed_signature}:#{product_signature}:#{timestamp_bucket}"
      hash = Digest::MD5.hexdigest(hash_input)[0..7]
      
      "tpl_#{template.template_id}:#{hash}:#{timestamp_bucket}"
    end
  end
end
