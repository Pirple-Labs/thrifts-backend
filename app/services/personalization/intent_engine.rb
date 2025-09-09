# frozen_string_literal: true

module Personalization
  class IntentEngine
    def self.drift?(session, snapshot, profile)
      # Check if user intent has changed significantly
      triggers = [
        new_search?(snapshot),
        category_shift?(session),
        recent_cart_activity?(snapshot),
        location_change?(session),
        profile_drift?(profile)
      ]
      
      triggers.any? && drift_score(triggers) > 0.3
    end
    
    def self.drift_score(triggers)
      # Calculate drift score based on trigger strength
      score = 0.0
      score += 0.4 if triggers[0]  # new search
      score += 0.3 if triggers[1]  # category shift
      score += 0.2 if triggers[2]  # recent cart activity
      score += 0.1 if triggers[3]  # location change
      score += 0.2 if triggers[4]  # profile drift
      score
    end
    
    private
    
    def self.new_search?(snapshot)
      # New search indicates intent change
      snapshot[:last_search].present?
    end
    
    def self.category_shift?(session)
      # 2+ PDPs in new category in ~3 minutes
      return false unless session.present?
      
      # Simplified for demo - in real implementation would analyze category patterns
      false
    end
    
    def self.recent_cart_activity?(snapshot)
      # ATC in last 30 minutes
      snapshot[:recent_add_to_cart]
    end
    
    def self.location_change?(session)
      # Region or pickup preference changed
      return false unless session.present?
      
      current_region = session[:region]
      current_pickup = session[:pickup_only]
      
      # This would need to be compared with stored session state
      # For now, return false as we don't have historical session data
      false
    end
    
    def self.profile_drift?(profile)
      # Significant change in user preferences
      # This would compare current profile with historical profile
      # Implementation depends on how you track profile evolution
      false  # Placeholder - would need historical profile storage
    end
  end
end
