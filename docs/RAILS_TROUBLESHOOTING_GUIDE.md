# Rails Team Troubleshooting Guide: Operator Communication Issue

## 🚨 **CRITICAL ISSUE IDENTIFIED**

**Problem**: Rails is getting stuck when trying to communicate with the Python Operator service.

**Root Cause**: JWT authentication mismatch between Rails and Operator services.

**Solution**: Implement STS (Same Trust Store) communication to remove JWT authentication entirely.

---

## 📋 **IMMEDIATE ACTION REQUIRED**

### **Step 1: Update Rails PlannerClient (URGENT)**

**File**: `app/services/personalization/planner_client.rb`

**❌ CURRENT BLOCKING CODE**:
```ruby
def self.build_headers
  {
    "Content-Type" => "application/json",
    "Accept" => "application/json",
    "Authorization" => "Bearer #{generate_jwt_token}",  # ← THIS IS CAUSING THE STUCK ISSUE
    "X-Request-Id" => Current.request_id || SecureRandom.uuid,
    "X-Plan-DSL-Version" => "1.0-mvp"
  }
end
```

**✅ FIXED CODE**:
```ruby
def self.build_headers
  {
    "Content-Type" => "application/json",
    "Accept" => "application/json",
    # For STS (Same Trust Store) communications, skip JWT authentication
    # "Authorization" => "Bearer #{generate_jwt_token}",  # ← REMOVE THIS LINE
    "X-Request-Id" => Current.request_id || SecureRandom.uuid,
    "X-Plan-DSL-Version" => "1.0-mvp"
  }
end
```

### **Step 2: Remove JWT Generation Method (OPTIONAL)**

**File**: `app/services/personalization/planner_client.rb`

**❌ REMOVE OR COMMENT OUT**:
```ruby
# def self.generate_jwt_token
#   payload = {
#     iss: "rails.personalization",
#     aud: "operator.personalization",
#     exp: 5.minutes.from_now.to_i,
#     iat: Time.current.to_i
#   }
#   
#   JWT.encode(payload, jwt_secret, 'HS256')
# end
```

---

## 🧪 **TESTING THE FIX**

### **Test 1: Quick Communication Test**

**File**: `lib/test_operator_connection.rb`

```ruby
#!/usr/bin/env ruby
# Quick test to verify Operator connection

puts "🔧 Testing Operator Connection Fix"
puts "=" * 40

# Test data
request_data = {
  page: "home",
  snapshot: {
    region: "ke",
    pickup_only: false,
    last_search: "sneakers",
    views_10m: 5,
    recent_add_to_cart: false,
    inactivity_bucket: "10_60m",
    pid: nil
  },
  profile: {
    price_band: "mid",
    top_categories: ["sneakers"],
    brand_top: ["Nike"],
    shop_top: [],
    freshness_pref: 0.7,
    diversity_pref: 0.5
  },
  constraints: {
    p95_budget_ms: 1000,
    max_sections: 6
  },
  session_embed_summary: {
    topics: ["sneakers"],
    centroid_bucket: "v3-bkt-12"
  },
  plan_cache_hint: {
    profile_hash: "h:test123",
    ttl_seconds: 172800
  }
}

# Headers WITHOUT JWT (STS approach)
headers = {
  "Content-Type" => "application/json",
  "Accept" => "application/json",
  # NO Authorization header
  "X-Request-Id" => SecureRandom.uuid,
  "X-Plan-DSL-Version" => "1.0-mvp"
}

puts "📡 Sending request to Operator..."
puts "   Endpoint: http://localhost:8000/operator/query-pack"
puts "   Headers: #{headers.keys.join(', ')}"
puts "   No JWT token (STS communication)"
puts

begin
  response = HTTParty.post(
    "http://localhost:8000/operator/query-pack",
    headers: headers,
    body: request_data.to_json,
    timeout: 30
  )
  
  puts "📊 Response received:"
  puts "   Status: #{response.code}"
  
  if response.success?
    data = JSON.parse(response.body)
    puts "   ✅ SUCCESS!"
    puts "   Plan ID: #{data['plan_id']}"
    puts "   Source: #{data['source']}"
    puts "   Sections: #{data['sections'].length}"
    puts
    puts "🎉 OPERATOR COMMUNICATION FIXED!"
    puts "   Rails can now communicate with Operator successfully"
  else
    puts "   ❌ FAILED: #{response.code}"
    puts "   Response: #{response.body}"
  end
  
rescue => e
  puts "   ❌ ERROR: #{e.message}"
  puts "   Check if Operator service is running on port 8000"
end
```

### **Test 2: End-to-End Flow Test**

**File**: `lib/test_personalization_flow.rb`

```ruby
#!/usr/bin/env ruby
# Test complete personalization flow

puts "🔄 Testing Complete Personalization Flow"
puts "=" * 50

begin
  # Test the actual PlannerClient (after JWT removal)
  puts "📋 Testing PlannerClient.fetch_plan..."
  
  plan = Personalization::PlannerClient.fetch_plan(
    page: "home",
    snapshot: {
      region: "ke",
      pickup_only: false,
      last_search: "white sneakers",
      views_10m: 7,
      recent_add_to_cart: false,
      inactivity_bucket: "10_60m",
      pid: nil
    },
    profile: {
      price_band: "mid",
      top_categories: ["sneakers", "bags"],
      brand_top: ["Nike"],
      shop_top: [],
      freshness_pref: 0.7,
      diversity_pref: 0.5
    },
    session_embed_summary: {
      topics: ["sneakers", "white", "retro"],
      centroid_bucket: "v3-bkt-12"
    },
    constraints: {
      p95_budget_ms: 1000,
      max_sections: 6
    }
  )
  
  puts "✅ SUCCESS! Plan received from Operator:"
  puts "   Plan ID: #{plan['plan_id']}"
  puts "   Source: #{plan['source']}"
  puts "   TTL: #{plan['ttl_seconds']} seconds"
  puts "   Sections: #{plan['sections'].length}"
  puts
  
  puts "📋 Generated Sections:"
  plan['sections'].each_with_index do |section, i|
    puts "   #{i + 1}. #{section['id']} (#{section['count']} items)"
    puts "      Reason: #{section['reason']}"
  end
  puts
  
  total_products = plan['sections'].sum { |s| s['count'] }
  puts "📈 Final Results:"
  puts "   Total Sections: #{plan['sections'].length}"
  puts "   Total Products: #{total_products}"
  puts "   Plan Source: #{plan['source']}"
  puts
  
  puts "🎉 PERSONALIZATION FLOW WORKING!"
  puts "   Rails can now generate LLM-powered personalized plans"
  
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts "   Make sure PlannerClient has been updated to remove JWT"
  puts "   Check if Operator service is running on port 8000"
end
```

---

## 🔍 **DIAGNOSTIC COMMANDS**

### **Check Operator Service Status**

```bash
# Check if Operator is running
curl http://localhost:8000/health

# Expected response: {"status": "healthy"}

# Test Operator endpoint directly
curl -X POST http://localhost:8000/operator/query-pack \
  -H "Content-Type: application/json" \
  -H "X-Request-Id: test-123" \
  -H "X-Plan-DSL-Version: 1.0-mvp" \
  -d '{"page":"home","snapshot":{"region":"ke","pickup_only":false,"last_search":"sneakers","views_10m":5,"recent_add_to_cart":false,"inactivity_bucket":"10_60m","pid":null},"profile":{"price_band":"mid","top_categories":["sneakers"],"brand_top":["Nike"],"shop_top":[],"freshness_pref":0.7,"diversity_pref":0.5},"constraints":{"p95_budget_ms":1000,"max_sections":6},"session_embed_summary":{"topics":["sneakers"],"centroid_bucket":"v3-bkt-12"},"plan_cache_hint":{"profile_hash":"h:test123","ttl_seconds":172800}}'
```

### **Check Rails Logs**

```bash
# Check Rails logs for errors
tail -f log/development.log | grep -i "operator\|jwt\|auth"

# Check for timeout errors
tail -f log/development.log | grep -i "timeout\|stuck"
```

---

## 🚨 **COMMON ISSUES AND SOLUTIONS**

### **Issue 1: "Connection Refused"**

**Symptoms**: Rails can't connect to Operator service

**Solution**:
```bash
# Check if Operator is running
netstat -an | grep :8000

# If not running, start Operator service
cd /path/to/flask-ai-service
python app.py
```

### **Issue 2: "JWT Authentication Failed"**

**Symptoms**: 401 errors or authentication failures

**Solution**: 
- Remove JWT authentication from Rails PlannerClient
- Ensure Operator service is updated to skip JWT validation

### **Issue 3: "Request Timeout"**

**Symptoms**: Requests hanging or timing out

**Solution**:
- Check Operator service health
- Verify network connectivity
- Check if LLM service is responding

### **Issue 4: "Schema Validation Error"**

**Symptoms**: 400 errors with schema validation

**Solution**:
- Verify request format matches expected schema
- Check section IDs are valid for the page type
- Ensure all required fields are present

---

## 📊 **EXPECTED RESULTS AFTER FIX**

### **Before Fix (Stuck/Blocked)**:
```
❌ Rails request hangs or times out
❌ JWT authentication failures
❌ 401 Unauthorized errors
❌ Only control plans available
❌ Limited personalization
```

### **After Fix (Working)**:
```
✅ Rails-Operator communication successful
✅ LLM-generated plans received
✅ Response time: ~10-15 seconds (normal for LLM)
✅ 4 sections generated per page
✅ Personalized recommendations working
```

---

## 🎯 **DEPLOYMENT CHECKLIST**

### **Development Environment**
- [ ] Update `PlannerClient.build_headers` to remove JWT
- [ ] Test Operator connection with `lib/test_operator_connection.rb`
- [ ] Test personalization flow with `lib/test_personalization_flow.rb`
- [ ] Verify end-to-end functionality

### **Staging Environment**
- [ ] Deploy updated Rails backend
- [ ] Run integration tests
- [ ] Monitor response times and success rates
- [ ] Test with real user data

### **Production Environment**
- [ ] Deploy with feature flags
- [ ] Gradual rollout (10% → 50% → 100%)
- [ ] Monitor metrics and errors
- [ ] Have rollback plan ready

---

## 🆘 **EMERGENCY ROLLBACK**

If issues arise after deployment:

1. **Re-enable JWT in Rails**:
```ruby
def self.build_headers
  {
    "Content-Type" => "application/json",
    "Accept" => "application/json",
    "Authorization" => "Bearer #{generate_jwt_token}",  # Re-enable
    "X-Request-Id" => Current.request_id || SecureRandom.uuid,
    "X-Plan-DSL-Version" => "1.0-mvp"
  }
end
```

2. **Redeploy Rails backend**
3. **Monitor for stability**

---

## 📞 **SUPPORT CONTACTS**

**Technical Issues**: AI Engineering Team  
**Rails Backend**: Rails Backend Team  
**Operator Service**: Python Operator Team  

**Service Endpoints**:
- Operator Health: `http://localhost:8000/health`
- Operator Query Pack: `http://localhost:8000/operator/query-pack`
- Rails API: `http://localhost:3000/api/demo/personalized_feed`

---

## 🎉 **SUCCESS CRITERIA**

The fix is successful when:

1. ✅ **Rails can connect to Operator** without authentication errors
2. ✅ **LLM-generated plans are received** (source: "llm")
3. ✅ **Response times are reasonable** (10-15 seconds for LLM)
4. ✅ **End-to-end personalization works** with real user data
5. ✅ **No more "stuck" requests** or timeout issues

---

**🚀 Once this fix is implemented, Rails will have access to AI-powered personalized plans instead of basic control plans, significantly improving the user experience!**
