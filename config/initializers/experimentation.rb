# Configuration for experimentation and A/B testing
Rails.application.config.after_initialize do
  # Feature flag for home ranker experiment
  EXP_HOME_RANKER = ENV.fetch('EXP_HOME_RANKER', 'false') == 'true'
  
  # Experiment configuration
  EXPERIMENT_CONFIG = {
    'home_ranker_ab_2025q3' => {
      status: ENV.fetch('EXP_HOME_RANKER_STATUS', 'draft'), # draft, running, paused, complete
      traffic_pct: ENV.fetch('EXP_HOME_RANKER_TRAFFIC', '10').to_i, # 10% traffic to operator
      description: 'A/B test for home feed ranking: Control vs Operator (LLM)'
    }
  }.freeze
  
  # Pricing configuration for cost tracking
  COST_PRICING = {
    gpt_token_usd: ENV.fetch('COST_GPT_TOKEN_USD', '0.0000020').to_f,      # $2.00 per million tokens
    gpu_usd_per_hour: ENV.fetch('COST_GPU_USD_PER_HOUR', '2.50').to_f,     # $2.50 per hour
    cpu_usd_per_hour: ENV.fetch('COST_CPU_USD_PER_HOUR', '0.05').to_f      # $0.05 per hour
  }.freeze
  
  Rails.logger.info "[Experimentation] Home ranker experiment: #{EXP_HOME_RANKER ? 'ENABLED' : 'DISABLED'}"
  Rails.logger.info "[Experimentation] Traffic allocation: #{EXPERIMENT_CONFIG['home_ranker_ab_2025q3'][:traffic_pct]}%"
  Rails.logger.info "[Experimentation] Status: #{EXPERIMENT_CONFIG['home_ranker_ab_2025q3'][:status]}"
end
