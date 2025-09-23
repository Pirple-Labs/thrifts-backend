# Plan DSL v1.2 Implementation Guide

## Overview

This document describes the implementation of the Plan DSL v1.2 contract in the Rails backend. The system provides a comprehensive personalization stack that works with an external Flask Operator service to deliver hyper-personalized product feeds.

## Architecture

### Core Components

1. **SnapshotBuilder** - Builds user context snapshots
2. **ProfileStore** - Manages user profile slices
3. **ProfileHasher** - Creates deterministic profile hashes for caching
4. **IntentEngine** - Detects user intent drift
5. **PlanCache** - Manages plan caching with neighbor reuse
6. **PlannerClient** - Communicates with the Flask Operator
7. **Retrieval Services** - Execute different retrieval strategies
8. **Guardrails** - Apply safety and business rules
9. **Coordination** - Bundle complementary products
10. **ResponseShaper** - Format final responses

### Data Flow

```
User Request → SnapshotBuilder → ProfileStore → ProfileHasher
     ↓
PlanCache (check cache) → PlannerClient (if miss) → Operator Service
     ↓
Execute Plan Sections → Retrieval → Guardrails → Coordination
     ↓
ResponseShaper → FeedExposure → Response
```

## API Endpoints

### POST /api/plan-dsl/start

Creates a personalized feed using the Plan DSL v1.2 contract.

**Request:**
```json
{
  "page": "home",
  "session_id": "session_123",
  "user_id": 123,
  "region": "ke",
  "pickup_only": false
}
```

**Response:**
```json
{
  "feed_id": "feed_uuid",
  "plan_id": "plan_123",
  "ttl_seconds": 172800,
  "sections": [
    {
      "id": "session_picks",
      "title": "Session Picks",
      "reason": "Based on your recent activity",
      "products": [...],
      "count": 12
    }
  ],
  "metadata": {
    "generated_at": "2025-01-15T10:30:00Z",
    "cache_hit": false,
    "total_latency_ms": 245.67,
    "profile_hash": "abc123",
    "intent_drift": false
  }
}
```

## Configuration

### Environment Variables

```bash
# Operator Service
PERSONALIZATION_OPERATOR_URL=http://localhost:5000
PERSONALIZATION_OPERATOR_API_KEY=your_api_key
PERSONALIZATION_OPERATOR_TIMEOUT=800

# Feature Flags
ENABLE_OPERATOR=true
ENABLE_NEIGHBOR_REUSE=true
ENABLE_RERANK_SLM=false

# Performance
PERSONALIZATION_MAX_POOL=200
PERSONALIZATION_TTL_SECONDS=300
PERSONALIZATION_CACHE_TTL=172800

# Algorithm Settings
PERSONALIZATION_ALPHA_RRF_DEFAULT=0.6
PERSONALIZATION_LAMBDA_DIVERSITY_DEFAULT=0.3
PERSONALIZATION_BETA_PRICE_TILT_DEFAULT=0.2
PERSONALIZATION_TAU_FRESH_DAYS_DEFAULT=14

# Guardrails
PERSONALIZATION_MERCHANT_CAP_PER_VIEWPORT=2
PERSONALIZATION_PRICE_BAND_TOLERANCE=0.8

# Monitoring
PERSONALIZATION_ENABLE_TELEMETRY=true
PERSONALIZATION_STATSD_HOST=localhost
PERSONALIZATION_STATSD_PORT=8125
```

## Plan DSL v1.2 Schema

The system expects plans in the following format:

```json
{
  "version": "1.2",
  "page": "home|search|pdp|profile",
  "constraints": {
    "p95_budget_ms": 1000,
    "max_sections": 6
  },
  "sections": [
    {
      "id": "session_picks|lookalikes|trending_near_you|...",
      "count": 12,
      "filters": {
        "categories": ["optional..."],
        "price_band": "low|mid|high",
        "fresh_days": 0,
        "region": "ke",
        "pickup_only": false,
        "favorites": false
      },
      "knobs": {
        "alpha_rrf": 0.6,
        "tau_fresh_days": 14,
        "lambda_diversity": 0.3,
        "beta_price_tilt": 0.2,
        "w_bundle": {
          "emb": 0.4,
          "copurch": 0.3,
          "attr": 0.2,
          "profile": 0.1
        }
      },
      "reason": "Because..."
    }
  ],
  "coordination": {
    "templates": [
      {
        "id": "complete_the_look",
        "slots": ["shoes", "bag"],
        "w": {
          "emb": 0.4,
          "copurch": 0.3,
          "attr": 0.2,
          "profile": 0.1
        }
      }
    ],
    "caps": {
      "per_merchant": 2,
      "per_viewport": 2
    }
  },
  "copy_style": {
    "tone": "friendly",
    "max_reason_len": 80
  }
}
```

## Retrieval Strategies

### SearchFusion
- Combines BM25 text search with vector similarity
- Uses Reciprocal Rank Fusion (RRF) with configurable alpha
- Applies diversity via Maximal Marginal Relevance (MMR)
- Includes price tilt adjustment

### Lookalikes
- Finds products similar to user's recent interactions
- Uses category, brand, and price similarity
- Applies diversity and price tilt

### Trending
- Identifies trending products based on recent activity
- Uses time-decayed scoring with configurable tau
- Applies diversity and price tilt

## Guardrails

The system applies several safety and business rules:

1. **Stock Check** - Only products with stock > 0
2. **Moderation** - Only approved products
3. **Region/Pickup** - Respects user preferences
4. **Price Band** - Fits user's price sensitivity
5. **Recent Purchases** - Excludes recently bought items
6. **Merchant Caps** - Limits items per merchant per viewport
7. **Cross-section Deduplication** - Prevents duplicates

## Coordination

The coordination system bundles complementary products:

1. **Complete the Look** - Matches shoes/bags with clothing
2. **Tech Accessories** - Pairs accessories with tech products
3. **Generic Coordination** - General complementary matching

## Caching Strategy

### Plan Cache
- Key format: `plan:{page}:{profile_hash}:v1.2`
- TTL: 48-72 hours
- Neighbor reuse for similar profiles

### Profile Hash
- Quantized representation of user profile
- Includes price band, categories, brands, preferences
- Enables efficient cache lookups

## Monitoring and Metrics

### FeedExposure Model
Tracks individual product exposures with:
- Retrieval latency
- Guardrails latency
- Coordination latency
- Propensity scores
- Drop reasons

### PlanMetric Model
Tracks plan performance with:
- Plan scores
- Cache hit rates
- Empty section rates
- Cost tracking
- Error rates

## Testing

### Contract Tests
- Validates Plan DSL schema compliance
- Tests retrieval strategies
- Verifies guardrails application
- Checks coordination logic

### Performance Tests
- Load testing with synthetic data
- Latency benchmarks
- Cache hit rate validation

## Deployment

### Prerequisites
1. Redis for caching
2. PostgreSQL with pgvector extension
3. Flask Operator service running
4. Environment variables configured

### Steps
1. Run database migrations
2. Start Rails application
3. Verify Operator connectivity
4. Monitor metrics and logs

## Troubleshooting

### Common Issues

1. **Operator Timeout**
   - Check Operator service health
   - Verify network connectivity
   - Review timeout settings

2. **Cache Misses**
   - Check Redis connectivity
   - Verify cache TTL settings
   - Review profile hash generation

3. **Empty Sections**
   - Check guardrails configuration
   - Verify product data quality
   - Review retrieval strategies

4. **High Latency**
   - Monitor database performance
   - Check vector search indexes
   - Review retrieval pool sizes

### Debugging

Enable debug logging:
```ruby
Rails.logger.level = :debug
```

Check plan cache:
```ruby
Rails.cache.read("plan:home:profile_hash:v1.2")
```

Monitor metrics:
```ruby
Personalization::PlanMetric.performance_summary("plan_id", 7)
```

## Future Enhancements

1. **RerankSLM** - Add section re-ranking
2. **PlanSLM** - Distill LLM to smaller model
3. **Real-time Learning** - Update models from feedback
4. **A/B Testing** - Experiment with different strategies
5. **Multi-modal** - Support image and text search

## Support

For issues or questions:
1. Check logs in `log/personalization.log`
2. Review metrics in admin dashboard
3. Contact the personalization team

