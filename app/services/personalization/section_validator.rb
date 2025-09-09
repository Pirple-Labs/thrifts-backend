# frozen_string_literal: true

module Personalization
  class SectionValidator
    # Allowed section IDs per page (MVP contract)
    ALLOWED_SECTIONS = {
      "home" => %w[session_picks lookalikes trending_near_you fresh_in_favorites],
      "search" => %w[search_results lookalikes trending_near_you],
      "pdp" => %w[similar_items complete_the_look more_from_shop],
      "profile" => %w[top_picks_for_you new_in_favorites from_shops_you_like]
    }.freeze
    
    def self.validate_plan(plan, page)
      errors = []
      
      # Validate page
      unless ALLOWED_SECTIONS.key?(page)
        errors << "Invalid page: #{page}"
        return errors
      end
      
      # Validate sections
      sections = plan[:sections] || []
      if sections.length > 6
        errors << "Too many sections: #{sections.length} (max 6)"
      end
      
      sections.each_with_index do |section, index|
        section_errors = validate_section(section, page, index)
        errors.concat(section_errors)
      end
      
      errors
    end
    
    def self.validate_section(section, page, index)
      errors = []
      
      # Validate section ID
      section_id = section[:id]
      unless ALLOWED_SECTIONS[page].include?(section_id)
        errors << "Section #{index}: Invalid section ID '#{section_id}' for page '#{page}'"
      end
      
      # Validate count
      count = section[:count]
      unless count.is_a?(Integer) && count > 0 && count <= 50
        errors << "Section #{index}: Invalid count #{count} (must be 1-50)"
      end
      
      # Validate reason length
      reason = section[:reason]
      if reason && reason.length > 80
        errors << "Section #{index}: Reason too long (#{reason.length} chars, max 80)"
      end
      
      # Validate filters
      filters = section[:filters] || {}
      filter_errors = validate_filters(filters, index)
      errors.concat(filter_errors)
      
      errors
    end
    
    def self.validate_filters(filters, section_index)
      errors = []
      
      # Validate price_band
      price_band = filters[:price_band]
      unless %w[low mid high].include?(price_band)
        errors << "Section #{section_index}: Invalid price_band '#{price_band}'"
      end
      
      # Validate fresh_days
      fresh_days = filters[:fresh_days]
      unless fresh_days.is_a?(Integer) && fresh_days >= 0
        errors << "Section #{section_index}: Invalid fresh_days #{fresh_days}"
      end
      
      # Validate region
      region = filters[:region]
      unless %w[ke].include?(region)
        errors << "Section #{section_index}: Invalid region '#{region}'"
      end
      
      # Validate pickup_only
      pickup_only = filters[:pickup_only]
      unless [true, false].include?(pickup_only)
        errors << "Section #{section_index}: Invalid pickup_only #{pickup_only}"
      end
      
      # Validate categories (if present)
      categories = filters[:categories]
      if categories && !categories.is_a?(Array)
        errors << "Section #{section_index}: Categories must be an array"
      end
      
      errors
    end
    
    def self.allowed_sections_for_page(page)
      ALLOWED_SECTIONS[page] || []
    end
    
    def self.is_valid_section?(section_id, page)
      ALLOWED_SECTIONS[page]&.include?(section_id) || false
    end
  end
end

