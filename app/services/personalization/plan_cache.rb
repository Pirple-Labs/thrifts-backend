# frozen_string_literal: true
module Personalization
  class PlanCache
    KEY = "plan:%s"

    def self.fetch(fingerprint)
      Rails.cache.read(KEY % fingerprint)
    end

    def self.store!(fingerprint:, plan:, ttl_seconds:)
      Rails.cache.write(KEY % fingerprint, plan, expires_in: ttl_seconds.seconds)
    end
    
    def self.get(page, profile_hash)
      # Try exact match first
      cache_key = "plan:#{page}:#{profile_hash}:v1.2"
      plan = Rails.cache.read(cache_key)
      return plan if plan
      
      # Try neighbor reuse
      neighbors = get_neighbors(profile_hash)
      nearest_plan = find_nearest_plan(neighbors, max_distance: 2)
      return nearest_plan if nearest_plan
      
      nil  # Cache miss
    end
    
    def self.set(page, profile_hash, plan, ttl: 172800)
      cache_key = "plan:#{page}:#{profile_hash}:v1.2"
      Rails.cache.write(cache_key, plan, expires_in: ttl.seconds)
      
      # Update neighbor index
      update_neighbor_index(profile_hash)
    end
    
    private
    
    def self.get_neighbors(profile_hash)
      Rails.cache.read("neighbors:#{profile_hash}") || []
    end
    
    def self.find_nearest_plan(neighbors, max_distance: 2)
      neighbors.each do |neighbor_hash|
        distance = hamming_distance(profile_hash, neighbor_hash)
        if distance <= max_distance
          cache_key = "plan:#{page}:#{neighbor_hash}:v1.2"
          plan = Rails.cache.read(cache_key)
          return plan if plan
        end
      end
      nil
    end
    
    def self.hamming_distance(hash1, hash2)
      # Calculate bit-wise distance between profile hashes
      hash1.chars.zip(hash2.chars).count { |a, b| a != b }
    end
    
    def self.update_neighbor_index(profile_hash)
      # Update neighbor index for future lookups
      neighbors = get_neighbors(profile_hash)
      neighbors << profile_hash unless neighbors.include?(profile_hash)
      Rails.cache.write("neighbors:#{profile_hash}", neighbors, expires_in: 7.days)
    end
  end
end


