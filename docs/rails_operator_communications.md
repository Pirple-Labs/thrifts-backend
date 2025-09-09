# Rails-Operator Communications Contract

## Overview

This document defines the communication contract between the Rails backend and the Flask Operator service for the personalization system MVP.

## API Contract

### Base URL
- **Production**: `https://operator.internal`
- **Development**: `http://localhost:5000`

### Endpoint
- **POST** `/operator/query-pack`

### Authentication
- **Type**: JWT Bearer Token
- **Header**: `Authorization: Bearer <token>`
- **Claims**:
  - `iss`: `rails.personalization`
  - `aud`: `operator.personalization`
  - `exp`: 5 minutes TTL

### Headers
```
Content-Type: application/json
Accept: application/json
X-Request-Id: <uuid>
X-Plan-DSL-Version: 1.0-mvp
```

### Timeouts
- **Rails Client**: 700ms read timeout
- **Operator Target**: ≤650ms total envelope
- **Fallback**: Control plan if timeout exceeded

## Request Format

```json
{
  "page": "home",
  "snapshot": {
    "region": "ke",
    "pickup_only": false,
    "last_search": "white sneakers",
    "views_10m": 7,
    "recent_add_to_cart": false,
    "inactivity_bucket": "10_60m",
    "pid": null
  },
  "profile": {
    "price_band": "mid",
    "top_categories": ["sneakers", "bags"],
    "brand_top": ["Nike"],
    "shop_top": [],
    "freshness_pref": 0.7,
    "diversity_pref": 0.5
  },
  "constraints": {
    "p95_budget_ms": 1000,
    "max_sections": 6
  },
  "session_embed_summary": {
    "topics": ["sneakers", "white", "retro"],
    "centroid_bucket": "v3-bkt-12"
  },
  "plan_cache_hint": {
    "profile_hash": "h:ab14cd09",
    "ttl_seconds": 172800
  }
}
```

## Response Format

```json
{
  "plan_id": "plan_2025-09-05T09:21:33Z_ab14cd09_home_v1",
  "source": "llm",
  "ttl_seconds": 172800,
  "page": "home",
  "sections": [
    {
      "id": "session_picks",
      "count": 12,
      "filters": {
        "categories": ["sneakers", "bags"],
        "price_band": "mid",
        "fresh_days": 14,
        "region": "ke",
        "pickup_only": false
      },
      "reason": "Because you viewed mid-price sneakers recently"
    }
  ],
  "copy_style": {
    "tone": "friendly",
    "max_reason_len": 80
  },
  "version": "1.0-mvp"
}
```

## Allowed Section IDs

### Home Page
- `session_picks`
- `lookalikes`
- `trending_near_you`
- `fresh_in_favorites`

### Search Page
- `search_results`
- `lookalikes`
- `trending_near_you`

### PDP Page
- `similar_items`
- `complete_the_look`
- `more_from_shop`

### Profile Page
- `top_picks_for_you`
- `new_in_favorites`
- `from_shops_you_like`

## Error Handling

### HTTP Status Codes
- **200**: Valid plan (llm or control)
- **400**: Schema validation error
- **401/403**: Authentication issues
- **408/504**: Timeout
- **5xx**: Server error

### Error Response Format
```json
{
  "error": {
    "code": "SCHEMA_INVALID|TIMEOUT|AUTH_FAILED|INTERNAL",
    "message": "human friendly",
    "details": {
      "field": "sections[0].id",
      "reason": "unknown_section"
    }
  }
}
```

### Rails Retry Policy
- **No retry** on 4xx errors
- **One retry** on 5xx/timeout with 50-100ms jitter
- **Always fallback** to control plan on failure

## Implementation Details

### Rails Client
```ruby
# app/services/personalization/planner_client.rb
module Personalization
  class PlannerClient
    ENDPOINT = ENV.fetch("PERSONALIZATION_OPERATOR_URL") + "/operator/query-pack"
    TIMEOUT_MS = Integer(ENV.fetch("OPERATOR_TIMEOUT_MS", 700))

    def self.fetch_plan(page:, snapshot:, profile:, session_embed_summary:, constraints:)
      # Implementation with JWT auth, timeout handling, and fallbacks
    end
  end
end
```

### JWT Token Generation
```ruby
def self.generate_jwt_token
  payload = {
    iss: "rails.personalization",
    aud: "operator.personalization",
    exp: 5.minutes.from_now.to_i,
    iat: Time.current.to_i
  }
  
  JWT.encode(payload, jwt_secret, 'HS256')
end
```

### Request ID Propagation
- Rails generates `X-Request-Id` UUID
- Propagated end-to-end for correlation
- Added to response headers

## Validation

### Section Validation
- Maximum 6 sections per page
- Only allowed section IDs for each page
- Reason text ≤80 characters
- Valid filter values

### Filter Validation
- `price_band`: `low|mid|high`
- `fresh_days`: Integer ≥0
- `region`: `ke`
- `pickup_only`: Boolean
- `categories`: Array of strings

## Control Plans

### Fallback Strategy
When Operator is unavailable or returns errors, Rails generates deterministic control plans:

```ruby
# app/services/personalization/planner_client.rb
class ControlPlan
  def self.for(page)
    case page
    when "home"
      {
        plan_id: "control_home_#{timestamp}",
        source: "control",
        ttl_seconds: 172800,
        page: "home",
        sections: [
          { id: "session_picks", count: 12, ... },
          { id: "lookalikes", count: 12, ... },
          { id: "trending_near_you", count: 12, ... }
        ],
        version: "1.0-mvp"
      }
    # ... other pages
    end
  end
end
```

## Testing

### Contract Tests
- Happy path with valid plan
- Timeout fallback to control plan
- Schema validation error handling
- Authentication error handling
- Server error with retry
- Request payload format validation

### Load Testing
- 100 RPS for 5 minutes
- Operator p95 ≤650ms
- Rails end-to-end p95 ≤1500ms
- Zero empty sections (backfill works)

## Monitoring

### Logging
- Request ID correlation
- Operator status (`ok|fallback|error`)
- Plan ID and source
- Section fill rates
- Guardrail drop counts

### Metrics
- Operator response time
- Cache hit rate
- Fallback rate
- Error rate by type
- Section fill rates

## Environment Variables

```bash
# Operator Service
PERSONALIZATION_OPERATOR_URL=https://operator.internal
OPERATOR_TIMEOUT_MS=700
PERSONALIZATION_JWT_SECRET=your_jwt_secret

# Feature Flags
ENABLE_OPERATOR=true
```

## Security

### JWT Security
- Short TTL (5 minutes)
- Proper issuer/audience validation
- Secret key rotation support

### Network Security
- HTTPS only in production
- Internal VPC communication
- Request ID correlation

### Data Privacy
- No SKUs or PII in requests
- Discretized session embeddings
- Profile hash for caching only

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Check JWT secret configuration
   - Verify token expiration
   - Validate issuer/audience claims

2. **Timeout Issues**
   - Check Operator service health
   - Verify network connectivity
   - Review timeout settings

3. **Schema Validation Errors**
   - Check section ID validity
   - Verify filter values
   - Review reason text length

4. **High Fallback Rate**
   - Monitor Operator performance
   - Check error logs
   - Verify service availability

### Debug Commands
```ruby
# Check JWT token
token = Personalization::PlannerClient.send(:generate_jwt_token)
JWT.decode(token, Personalization::PlannerClient.send(:jwt_secret), true)

# Test control plan
plan = Personalization::PlannerClient.control_plan("home")

# Validate section
errors = Personalization::SectionValidator.validate_plan(plan, "home")
```

## Future Enhancements

1. **Versioning**: Support for Plan DSL v1.2+
2. **Caching**: Operator-side plan caching
3. **Metrics**: Enhanced observability
4. **Security**: Enhanced JWT validation
5. **Performance**: Connection pooling
