# AI Team Issue Report: Python Operator Communication Problem

## 🚨 **CRITICAL ISSUE IDENTIFIED**

The Rails-Operator communication is **partially working** but has a **critical timeout issue** that needs immediate attention from the AI team.

## 📊 **Current Status Summary**

### ✅ **What's Working**
- **Rails Backend**: Fully functional with STS communication (JWT removed)
- **Python Operator**: Running and healthy on port 8000
- **Basic Connectivity**: Python Operator responds to health checks
- **Authentication**: STS communication working (no JWT required)

### ❌ **What's Broken**
- **Python Operator `/operator/query-pack` endpoint**: **TIMING OUT** on all requests
- **LLM Plan Generation**: Cannot receive AI-generated plans
- **End-to-End Flow**: Falls back to control plans only

## 🔍 **Detailed Problem Analysis**

### **Issue 1: Endpoint Timeout**
```
Request: POST http://localhost:8000/operator/query-pack
Status: TIMEOUT (10+ seconds)
Result: Rails falls back to control plans
```

### **Issue 2: Request Validation**
When we tested with a minimal payload, the Python Operator correctly returned:
```json
{
  "error": {
    "code": "SCHEMA_INVALID",
    "message": "Validation failed",
    "details": "4 validation errors for MVPQueryPackRequest\nsnapshot\n Field required\nprofile\n Field required\nconstraints\n Field required\nsession_embed_summary\n Field required"
  }
}
```

**This proves**:
- ✅ Python Operator is running and accessible
- ✅ It accepts requests without JWT authentication
- ✅ It validates request schema correctly
- ❌ **It hangs/timeouts when processing complete valid requests**

## 🧪 **Test Results**

### **Test 1: Health Check**
```bash
curl http://localhost:8000/health
# Result: ✅ 200 OK - {"status": "healthy"}
```

### **Test 2: Minimal Request**
```bash
curl -X POST http://localhost:8000/operator/query-pack -H "Content-Type: application/json" -d '{"page":"home"}'
# Result: ✅ 400 Bad Request - Schema validation error (expected)
```

### **Test 3: Complete Request**
```bash
# Full payload with all required fields
# Result: ❌ TIMEOUT - No response after 10+ seconds
```

## 🔧 **Root Cause Analysis**

The Python Operator is **hanging** when processing complete requests. Possible causes:

### **Most Likely Causes**
1. **LLM Processing Issue**: The LLM call is hanging or taking too long
2. **Database Connection**: Hanging on database queries
3. **External API Calls**: Timeout on external service calls
4. **Infinite Loop**: Logic error causing infinite processing
5. **Resource Exhaustion**: Memory/CPU issues

### **Less Likely Causes**
1. **Request Size**: Payload too large (481 bytes is small)
2. **Network Issues**: Local network problems
3. **Python GIL**: Global Interpreter Lock issues

## 🎯 **Immediate Action Required from AI Team**

### **Step 1: Debug Python Operator Logs**
```bash
# Check Python Operator logs for:
# - Error messages
# - Hanging processes
# - LLM call failures
# - Database connection issues
```

### **Step 2: Test LLM Integration**
```python
# Test if LLM calls are working:
# - OpenAI API connectivity
# - Model response times
# - Token limits
# - Rate limiting
```

### **Step 3: Add Timeout Handling**
```python
# Add proper timeout handling to Python Operator:
# - LLM call timeouts
# - Database query timeouts
# - Overall request timeout
```

### **Step 4: Add Debug Logging**
```python
# Add detailed logging to identify where it hangs:
# - Request received
# - LLM call started
# - LLM call completed
# - Response sent
```

## 📋 **Expected Request Format**

The Python Operator should handle this complete request format:

```json
{
  "page": "home",
  "snapshot": {
    "region": "ke",
    "pickup_only": false,
    "last_search": "",
    "views_10m": 0,
    "recent_add_to_cart": false,
    "inactivity_bucket": "dormant",
    "pid": null
  },
  "profile": {
    "price_band": "low",
    "top_categories": [],
    "brand_top": [],
    "shop_top": [],
    "freshness_pref": 0.5,
    "diversity_pref": 0.5
  },
  "constraints": {
    "p95_budget_ms": 1000,
    "max_sections": 6
  },
  "session_embed_summary": {
    "topics": ["test"],
    "centroid_bucket": "test-bkt-01"
  },
  "plan_cache_hint": {
    "profile_hash": "test_hash",
    "ttl_seconds": 172800
  }
}
```

## 📊 **Expected Response Format**

The Python Operator should return:

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
    }
  ],
  "copy_style": {
    "tone": "friendly",
    "max_reason_len": 80
  },
  "version": "1.0-mvp"
}
```

## 🚀 **Quick Fix Options**

### **Option 1: Add Timeout to Python Operator**
```python
import signal

def timeout_handler(signum, frame):
    raise TimeoutError("Request timeout")

# Set 5-second timeout
signal.signal(signal.SIGALRM, timeout_handler)
signal.alarm(5)

try:
    # Process request
    result = process_request(request_data)
    signal.alarm(0)  # Cancel timeout
    return result
except TimeoutError:
    return control_plan(request_data)
```

### **Option 2: Add Debug Logging**
```python
import logging

@app.post("/operator/query-pack")
def query_pack():
    logging.info("Request received")
    
    try:
        request_data = request.get_json()
        logging.info("Request parsed successfully")
        
        # LLM call
        logging.info("Starting LLM call")
        plan = generate_llm_plan(request_data)
        logging.info("LLM call completed")
        
        return plan, 200
    except Exception as e:
        logging.error(f"Error processing request: {e}")
        return control_plan(request_data), 200
```

### **Option 3: Fallback to Control Plan**
```python
@app.post("/operator/query-pack")
def query_pack():
    try:
        # Try LLM plan with timeout
        plan = generate_llm_plan_with_timeout(request_data, timeout=5)
        return plan, 200
    except TimeoutError:
        # Fallback to control plan
        return control_plan(request_data), 200
```

## 📈 **Success Criteria**

The issue will be resolved when:

1. ✅ **Python Operator responds within 5 seconds**
2. ✅ **Returns valid LLM-generated plans**
3. ✅ **Rails receives `source: "llm"` instead of `source: "control"`
4. ✅ **End-to-end personalization flow works with AI plans**

## 🔧 **Testing Commands for AI Team**

### **Test 1: Check Python Operator Logs**
```bash
# Look for error messages, hanging processes, or timeouts
tail -f /path/to/python/operator/logs
```

### **Test 2: Test LLM Connectivity**
```python
# Test if LLM calls are working
import openai
response = openai.ChatCompletion.create(
    model="gpt-3.5-turbo",
    messages=[{"role": "user", "content": "test"}],
    timeout=5
)
```

### **Test 3: Test Database Connectivity**
```python
# Test if database queries are working
import psycopg2
conn = psycopg2.connect("your_connection_string")
cursor = conn.cursor()
cursor.execute("SELECT 1")
result = cursor.fetchone()
```

### **Test 4: Test Complete Request**
```bash
# Test with complete payload
curl -X POST http://localhost:8000/operator/query-pack \
  -H "Content-Type: application/json" \
  -d '{
    "page": "home",
    "snapshot": {"region": "ke", "pickup_only": false, "last_search": "", "views_10m": 0, "recent_add_to_cart": false, "inactivity_bucket": "dormant", "pid": null},
    "profile": {"price_band": "low", "top_categories": [], "brand_top": [], "shop_top": [], "freshness_pref": 0.5, "diversity_pref": 0.5},
    "constraints": {"p95_budget_ms": 1000, "max_sections": 6},
    "session_embed_summary": {"topics": ["test"], "centroid_bucket": "test-bkt-01"},
    "plan_cache_hint": {"profile_hash": "test_hash", "ttl_seconds": 172800}
  }'
```

## 📞 **Next Steps**

1. **AI Team**: Debug Python Operator timeout issue
2. **AI Team**: Add proper timeout handling and logging
3. **AI Team**: Test LLM integration and database connectivity
4. **Rails Team**: Wait for Python Operator fix
5. **Both Teams**: Test end-to-end communication once fixed

## 🎯 **Priority Level: HIGH**

This is blocking the entire AI-powered personalization system. The Rails backend is ready and waiting for the Python Operator to respond properly.

---

**Document Version**: 1.0  
**Date**: September 6, 2025  
**Author**: Rails Backend Team  
**Target Audience**: AI Team (Python Operator Team)

