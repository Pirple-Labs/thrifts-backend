# frozen_string_literal: true

# Personalization Configuration
Rails.application.configure do
  # Operator service configuration (MVP contract)
  config.personalization_operator_url = ENV['PERSONALIZATION_OPERATOR_URL'] || 'https://operator.internal'
  config.personalization_operator_timeout = ENV['OPERATOR_TIMEOUT_MS']&.to_i || 700
  config.personalization_jwt_secret = ENV['PERSONALIZATION_JWT_SECRET'] || Rails.application.secret_key_base
  
  # Feature flags
  config.enable_operator = ENV['ENABLE_OPERATOR'] == 'true'
  config.enable_neighbor_reuse = ENV['ENABLE_NEIGHBOR_REUSE'] == 'true'
  config.enable_rerank_slm = ENV['ENABLE_RERANK_SLM'] == 'true'
  
  # Performance settings
  config.personalization_max_pool = ENV['PERSONALIZATION_MAX_POOL']&.to_i || 200
  config.personalization_ttl_seconds = ENV['PERSONALIZATION_TTL_SECONDS']&.to_i || 300
  config.personalization_fallback_ttl = ENV['PERSONALIZATION_FALLBACK_TTL']&.to_i || 60
  
  # Cache settings
  config.personalization_cache_ttl = ENV['PERSONALIZATION_CACHE_TTL']&.to_i || 172800  # 48 hours
  config.personalization_neighbor_max_distance = ENV['PERSONALIZATION_NEIGHBOR_MAX_DISTANCE']&.to_i || 2
  
  # Algorithm settings
  config.personalization_alpha_rrf_default = ENV['PERSONALIZATION_ALPHA_RRF_DEFAULT']&.to_f || 0.6
  config.personalization_lambda_diversity_default = ENV['PERSONALIZATION_LAMBDA_DIVERSITY_DEFAULT']&.to_f || 0.3
  config.personalization_beta_price_tilt_default = ENV['PERSONALIZATION_BETA_PRICE_TILT_DEFAULT']&.to_f || 0.2
  config.personalization_tau_fresh_days_default = ENV['PERSONALIZATION_TAU_FRESH_DAYS_DEFAULT']&.to_i || 14
  
  # Guardrails settings
  config.personalization_merchant_cap_per_viewport = ENV['PERSONALIZATION_MERCHANT_CAP_PER_VIEWPORT']&.to_i || 2
  config.personalization_price_band_tolerance = ENV['PERSONALIZATION_PRICE_BAND_TOLERANCE']&.to_f || 0.8
  
  # Monitoring settings
  config.personalization_enable_telemetry = ENV['PERSONALIZATION_ENABLE_TELEMETRY'] == 'true'
  config.personalization_statsd_host = ENV['PERSONALIZATION_STATSD_HOST'] || 'localhost'
  config.personalization_statsd_port = ENV['PERSONALIZATION_STATSD_PORT']&.to_i || 8125
end

# Make configuration available to services
module Personalization
  module Config
    extend self
    
    def operator_url
      Rails.application.config.personalization_operator_url
    end
    
    def operator_timeout
      Rails.application.config.personalization_operator_timeout
    end
    
    def jwt_secret
      Rails.application.config.personalization_jwt_secret
    end
    
    def enable_operator?
      Rails.application.config.enable_operator
    end
    
    def enable_neighbor_reuse?
      Rails.application.config.enable_neighbor_reuse
    end
    
    def enable_rerank_slm?
      Rails.application.config.enable_rerank_slm
    end
    
    def max_pool
      Rails.application.config.personalization_max_pool
    end
    
    def ttl_seconds
      Rails.application.config.personalization_ttl_seconds
    end
    
    def fallback_ttl
      Rails.application.config.personalization_fallback_ttl
    end
    
    def cache_ttl
      Rails.application.config.personalization_cache_ttl
    end
    
    def neighbor_max_distance
      Rails.application.config.personalization_neighbor_max_distance
    end
    
    def alpha_rrf_default
      Rails.application.config.personalization_alpha_rrf_default
    end
    
    def lambda_diversity_default
      Rails.application.config.personalization_lambda_diversity_default
    end
    
    def beta_price_tilt_default
      Rails.application.config.personalization_beta_price_tilt_default
    end
    
    def tau_fresh_days_default
      Rails.application.config.personalization_tau_fresh_days_default
    end
    
    def merchant_cap_per_viewport
      Rails.application.config.personalization_merchant_cap_per_viewport
    end
    
    def price_band_tolerance
      Rails.application.config.personalization_price_band_tolerance
    end
    
    def enable_telemetry?
      Rails.application.config.personalization_enable_telemetry
    end
    
    def statsd_host
      Rails.application.config.personalization_statsd_host
    end
    
    def statsd_port
      Rails.application.config.personalization_statsd_port
    end
  end
end