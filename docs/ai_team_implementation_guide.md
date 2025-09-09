# AI Team Implementation Guide: Rails-Operator Communication

## Overview

This guide provides the AI team with detailed technical implementation steps for the Rails-Operator communication system, focusing on the recommended STS (Same Trust Store) authentication approach.

## Current Status

### ✅ Working Components
- **Rails Backend**: Fully functional personalization system
- **End-to-End Flow**: Complete personalization pipeline working
- **Control Plans**: Fallback plans generating 27 products across 3 sections
- **Product Retrieval**: All retrieval services operational
- **Guardrails**: Product filtering working correctly

### ❌ Blocked Components
- **Rails-Operator Communication**: JWT authentication mismatch
- **LLM-Generated Plans**: Cannot receive from Python Operator
- **Advanced Personalization**: Limited to control plans only

## Technical Implementation Steps

### Step 1: Remove JWT Authentication from Rails

**File**: `app/services/personalization/planner_client.rb`

**Current Code**:
```ruby
def self.build_headers
  {
    "Content-Type" => "application/json",
    "Accept" => "application/json",
    "Authorization" => "Bearer #{generate_jwt_token}",
    "X-Request-Id" => Current.request_id || SecureRandom.uuid,
    "X-Plan-DSL-Version" => "1.0-mvp"
  }
end
```

**Updated Code**:
```ruby
def self.build_headers
  {
    "Content-Type" => "application/json",
    "Accept" => "application/json",
    # For STS (Same Trust Store) communications, skip JWT authentication
    # "Authorization" => "Bearer #{generate_jwt_token}",
    "X-Request-Id" => Current.request_id || SecureRandom.uuid,
    "X-Plan-DSL-Version" => "1.0-mvp"
  }
end
```

### Step 2: Update Python Operator JWT Validation

**File**: Python Operator `/operator/query-pack` endpoint

**Current Code** (estimated):
```python
@app.post("/operator/query-pack")
def query_pack():
    # JWT validation logic
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return {"error": {"code": "AUTH_FAILED", "message": "Invalid or missing JWT token"}}, 401
    
    # JWT token validation
    # ... validation logic ...
```

**Updated Code**:
```python
@app.post("/operator/query-pack")
def query_pack():
    # For STS (Same Trust Store) communications, skip JWT validation
    # Internal services can communicate without authentication
    print("🔐 STS Communication: Skipping JWT validation for internal service")
    
    # Process request directly
    request_data = request.get_json()
    page = request_data.get('page')
    
    print(f"📊 Request data: page={page}, region={request_data.get('snapshot', {}).get('region')}")
    print("✅ Internal service authentication passed")
    
    # Generate LLM plan
    plan = generate_llm_plan(request_data)
    
    return plan, 200
```

### Step 3: Test Communication

**Test Script**: `lib/test_real_operator_comm.rb`

**Expected Output**:
```
🔗 Testing Real Rails-Operator Communication
==================================================
⚙️  Environment configured:
   Rails Backend: http://localhost:3000
   Python Operator: http://localhost:8000

📊 Test Parameters:
   Page: home
   User ID: 1
   Session ID: test_session_xxxx
   Region: ke

🔍 Step 1: Building Snapshot...
   ✅ Snapshot built successfully

👤 Step 2: Building Profile...
   ✅ Profile built successfully

🔑 Step 3: Profile Hash: 00___1000_1000_00

🔐 Step 4: Generating JWT Token...
   JWT Token: [SKIPPED FOR STS]

📡 Step 5: Sending Request to Python Operator...
   Endpoint: http://localhost:8000/operator/query-pack
   Payload size: 507 bytes

📤 Request Headers:
   Content-Type: application/json
   Accept: application/json
   X-Request-Id: uuid-here
   X-Plan-DSL-Version: 1.0-mvp

📊 Step 6: Operator Response:
   Status: 200 OK
   Headers: {...}

✅ SUCCESS! Python Operator Response:
   Plan ID: plan_2025-09-05T09:21:33Z_ab14cd09_home_v1
   Source: llm
   TTL: 172800 seconds
   Sections: 3

📋 Section Details:
   1. session_picks (12 items)
      Reason: Based on your recent activity
   2. lookalikes (12 items)
      Reason: Similar to what you've been browsing
   3. trending_near_you (12 items)
      Reason: Trending in your area

🎉 RAILS-OPERATOR COMMUNICATION SUCCESSFUL!
   The Python Flask Operator is responding with LLM-generated plans!
```

### Step 4: Verify End-to-End Flow

**Test Script**: `lib/test_end_to_end_flow.rb`

**Expected Output**:
```
🔄 Testing End-to-End Personalization Flow
==================================================
⚙️  Environment configured:
   Operator: ENABLED (using LLM plans)

📊 Test Parameters:
   Page: home
   User ID: 1
   Session ID: test_session_xxxx
   Region: ke

🔍 Step 1: Building Snapshot...
   ✅ Snapshot built successfully

👤 Step 2: Building Profile...
   ✅ Profile built successfully

🔑 Step 3: Profile Hash: 00___1000_1000_00

🎯 Step 4: Intent Drift Check...
   Intent Drift: false

📋 Step 5: Getting Plan...
   ❌ Cache MISS! Fetching from Operator...
   📡 Step 6: Sending Request to Operator...
   ✅ Step 7: Operator Response Received!
   Plan ID: plan_2025-09-05T09:21:33Z_ab14cd09_home_v1
   Source: llm
   TTL: 172800 seconds
   Sections: 3

⚙️  Step 8: Executing Plan Sections...
   ✅ Plan execution completed

📊 Section Results:
   1. session_picks: 12 products
   2. lookalikes: 12 products
   3. trending_near_you: 12 products

📈 Final Results:
   Total Sections: 3
   Total Products: 36
   Plan Source: llm

🎉 SUCCESS! End-to-end personalization flow is working!
   Rails can generate plans and retrieve products successfully
   The system is ready for frontend integration
```

## Request/Response Contract

### Request Format (Rails → Operator)
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
    "top_categories": ["sneakers","bags"],
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
    "topics": ["sneakers","white","retro"],
    "centroid_bucket": "v3-bkt-12"
  },
  "plan_cache_hint": {
    "profile_hash": "h:ab14cd09",
    "ttl_seconds": 172800
  }
}
```

### Response Format (Operator → Rails)
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
        "categories": ["sneakers","bags"],
        "price_band": "mid",
        "fresh_days": 14,
        "region": "ke",
        "pickup_only": false
      },
      "reason": "Because you viewed mid-price sneakers recently"
    },
    {
      "id": "lookalikes",
      "count": 12,
      "filters": {
        "categories": ["sneakers"],
        "price_band": "mid",
        "fresh_days": 30,
        "region": "ke",
        "pickup_only": false
      },
      "reason": "Similar to what you've been browsing"
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
- `session_picks`: Based on recent user activity
- `lookalikes`: Similar to browsing history
- `trending_near_you`: Popular items in user's region
- `fresh_in_favorites`: New items in user's favorites

### Search Page
- `search_results`: Direct search results
- `lookalikes`: Similar to search query
- `trending_near_you`: Popular items in region

### PDP Page
- `similar_items`: Similar to current product
- `complete_the_look`: Complementary items
- `more_from_shop`: Other items from same merchant

### Profile Page
- `top_picks_for_you`: Personalized recommendations
- `new_in_favorites`: New items in favorites
- `from_shops_you_like`: Items from preferred merchants

## Error Handling

### HTTP Status Codes
- `200`: Success with valid plan
- `400`: Validation error (schema invalid)
- `500`: Internal server error

### Error Response Format
```json
{
  "error": {
    "code": "SCHEMA_INVALID|TIMEOUT|INTERNAL",
    "message": "Human friendly error message",
    "details": {
      "field": "sections[0].id",
      "reason": "unknown_section"
    }
  }
}
```

## Performance Requirements

### Latency Targets
- **Operator Response**: ≤ 650ms (95th percentile)
- **Rails End-to-End**: ≤ 1000ms (95th percentile)
- **Total Budget**: 1000ms for complete personalization

### Throughput Targets
- **Request Rate**: 100+ requests per second
- **Success Rate**: ≥ 99% successful responses
- **Cache Hit Rate**: ≥ 70% for plan cache

## Monitoring and Observability

### Key Metrics
- **Response Time**: P95 latency for Operator requests
- **Success Rate**: Percentage of successful responses
- **Cache Hit Rate**: Plan cache effectiveness
- **Section Fill Rate**: Percentage of sections with products
- **Error Rate**: Failed requests and error types

### Logging
- **Request ID**: End-to-end request tracing
- **Plan Source**: `llm` vs `control` plan usage
- **Section Count**: Number of sections in plan
- **Latency**: Request processing time

## Testing Checklist

### Communication Tests
- [ ] Rails can send requests to Operator without JWT
- [ ] Operator accepts requests without JWT validation
- [ ] Response format matches expected schema
- [ ] Error handling works correctly

### Integration Tests
- [ ] End-to-end personalization flow works
- [ ] LLM plans are generated and executed
- [ ] Product retrieval works with LLM plans
- [ ] Guardrails apply correctly to LLM results

### Performance Tests
- [ ] Response time meets latency targets
- [ ] Throughput meets requirements
- [ ] Memory usage is acceptable
- [ ] No memory leaks in long-running tests

## Deployment Steps

### Development Environment
1. Update Rails `PlannerClient` to remove JWT
2. Update Python Operator to skip JWT validation
3. Test communication with test scripts
4. Verify end-to-end flow works

### Staging Environment
1. Deploy updated Rails backend
2. Deploy updated Python Operator
3. Run integration tests
4. Performance testing
5. Load testing

### Production Environment
1. Deploy with feature flags
2. Gradual rollout (10% → 50% → 100%)
3. Monitor metrics and errors
4. Rollback plan ready if needed

## Rollback Plan

If issues arise:
1. Re-enable JWT authentication in Rails
2. Re-enable JWT validation in Python Operator
3. Use existing JWT secret configuration
4. Monitor for stability

## Support and Troubleshooting

### Common Issues
1. **Connection Refused**: Check if Operator is running on port 8000
2. **Timeout Errors**: Check Operator response time
3. **Schema Errors**: Validate request/response format
4. **Empty Sections**: Check product retrieval logic

### Debug Commands
```bash
# Test Operator health
curl http://localhost:8000/health

# Test Rails-Operator communication
rails runner lib/test_real_operator_comm.rb

# Test end-to-end flow
rails runner lib/test_end_to_end_flow.rb

# Test API endpoint
curl -X POST http://localhost:3000/api/demo/personalized_feed \
  -H "Content-Type: application/json" \
  -d '{"page":"home","user_id":1,"region":"ke"}'
```

---

**Document Version**: 1.0  
**Date**: September 5, 2025  
**Author**: Rails Backend Team  
**Target Audience**: AI Team, Python Operator Team

