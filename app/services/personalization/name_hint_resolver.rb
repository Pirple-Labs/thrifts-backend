# frozen_string_literal: true

module Personalization
  class NameHintResolver
    # Product type mappings for hint resolution
    PRODUCT_TYPE_MAPPINGS = {
      # Laptop accessories
      'laptop stand' => { category: 'electronics', type: 'laptop_stand', attributes: ['adjustable', 'aluminum'] },
      'wireless mouse' => { category: 'electronics', type: 'mouse', attributes: ['wireless', 'bluetooth'] },
      'laptop bag' => { category: 'bags', type: 'laptop_bag', attributes: ['15-inch', 'waterproof'] },
      'usb-c hub' => { category: 'electronics', type: 'hub', attributes: ['usb-c', 'multi-port'] },
      'external monitor' => { category: 'electronics', type: 'monitor', attributes: ['24-inch', 'hdmi'] },
      
      # Gaming setup
      'gaming desk' => { category: 'furniture', type: 'desk', attributes: ['gaming', 'adjustable'] },
      'gaming chair' => { category: 'furniture', type: 'chair', attributes: ['gaming', 'ergonomic'] },
      'rgb lighting' => { category: 'electronics', type: 'lighting', attributes: ['rgb', 'led'] },
      'mouse pad' => { category: 'electronics', type: 'mouse_pad', attributes: ['gaming', 'large'] },
      'headphone stand' => { category: 'furniture', type: 'stand', attributes: ['headphone', 'wood'] },
      
      # Phone accessories
      'phone case' => { category: 'electronics', type: 'phone_case', attributes: ['protective', 'clear'] },
      'screen protector' => { category: 'electronics', type: 'screen_protector', attributes: ['tempered_glass', '9h'] },
      'wireless charger' => { category: 'electronics', type: 'charger', attributes: ['wireless', 'fast_charge'] },
      'car mount' => { category: 'electronics', type: 'mount', attributes: ['car', 'magnetic'] },
      
      # Home office
      'desk lamp' => { category: 'furniture', type: 'lamp', attributes: ['led', 'adjustable'] },
      'desk organizer' => { category: 'furniture', type: 'organizer', attributes: ['wood', 'multi-compartment'] },
      'cable management' => { category: 'electronics', type: 'cable_management', attributes: ['cable_tray', 'organizer'] }
    }.freeze

    def self.resolve_hints(hints, request_id:, page:, section_id:)
      return [] unless hints&.dig('product_types')&.any?

      resolved_hints = []
      
      hints['product_types'].each do |hint_text|
        resolution = resolve_single_hint(hint_text, hints, request_id, page, section_id)
        resolved_hints << resolution if resolution[:confidence] >= 0.6
      end
      
      resolved_hints
    end

    private

    def self.resolve_single_hint(hint_text, hints, request_id, page, section_id)
      # Normalize hint text
      normalized_hint = normalize_hint_text(hint_text)
      
      # Try exact match first
      if PRODUCT_TYPE_MAPPINGS.key?(normalized_hint)
        mapping = PRODUCT_TYPE_MAPPINGS[normalized_hint]
        confidence = 0.9
        
        # Log the resolution
        log_hint_resolution(request_id, page, section_id, hint_text, mapping[:type], confidence)
        
        return {
          hint_text: hint_text,
          resolved_type: mapping[:type],
          category: mapping[:category],
          attributes: mapping[:attributes],
          confidence: confidence,
          inventory_supported: check_inventory_support(mapping)
        }
      end
      
      # Try fuzzy matching
      fuzzy_match = find_fuzzy_match(normalized_hint)
      if fuzzy_match
        confidence = 0.7
        
        # Log the resolution
        log_hint_resolution(request_id, page, section_id, hint_text, fuzzy_match[:type], confidence)
        
        return {
          hint_text: hint_text,
          resolved_type: fuzzy_match[:type],
          category: fuzzy_match[:category],
          attributes: fuzzy_match[:attributes],
          confidence: confidence,
          inventory_supported: check_inventory_support(fuzzy_match)
        }
      end
      
      # No resolution found
      log_hint_resolution(request_id, page, section_id, hint_text, nil, 0.0)
      
      {
        hint_text: hint_text,
        resolved_type: nil,
        category: nil,
        attributes: [],
        confidence: 0.0,
        inventory_supported: false
      }
    end

    def self.normalize_hint_text(hint_text)
      hint_text.downcase.strip
               .gsub(/[^\w\s]/, '') # Remove punctuation
               .gsub(/\s+/, ' ')    # Normalize whitespace
               .strip
    end

    def self.find_fuzzy_match(normalized_hint)
      # Simple fuzzy matching - look for partial matches
      PRODUCT_TYPE_MAPPINGS.each do |key, mapping|
        # Check if hint contains key words or vice versa
        if normalized_hint.include?(key) || key.include?(normalized_hint)
          return mapping
        end
        
        # Check for word overlap
        hint_words = normalized_hint.split(' ')
        key_words = key.split(' ')
        
        overlap = hint_words & key_words
        if overlap.length >= 2 # At least 2 words match
          return mapping
        end
      end
      
      nil
    end

    def self.check_inventory_support(mapping)
      # Check if we have products in this category/type
      Product.joins(:shop)
             .where(category: mapping[:category])
             .where("products.stock > 0")
             .where("products.moderation_status = ?", "approved")
             .exists?
    end

    def self.log_hint_resolution(request_id, page, section_id, hint_text, resolved_type_id, confidence)
      HintResolution.create!(
        request_id: request_id,
        page: page,
        section_id: section_id,
        hint_text: hint_text,
        resolved_type_id: resolved_type_id,
        confidence: confidence,
        inventory_supported: resolved_type_id.present?
      )
    rescue => e
      Rails.logger.error("Failed to log hint resolution: #{e.message}")
    end
  end
end



