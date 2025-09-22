# JWT Authentication Plan for Rails-Operator Communication

## Executive Summary

This document outlines the authentication strategy for the Rails-Operator communication system in our intelligent shopping assistant. After analysis and testing, we recommend **removing JWT authentication** for internal service-to-service communication within our trusted environment.

## Current System Architecture

```
┌─────────────────┐    HTTP/JSON    ┌─────────────────┐
│   Rails Backend │ ──────────────► │ Python Operator │
│   (Port 3000)   │                 │   (Port 8000)   │
└─────────────────┘                 └─────────────────┘
```

## Authentication Options Analysis

### Option 1: JWT Authentication (Current Implementation)
**Status**: ❌ **BLOCKED** - Authentication mismatch between services

**Implementation**:
- Rails generates JWT tokens with claims: `iss`, `aud`, `exp`, `iat`
- Python Operator validates JWT tokens
- **Issue**: Different JWT secrets/validation logic causing `401 AUTH_FAILED`

**JWT Token Structure**:
```json
{
  "iss": "rails.personalization",
  "aud": "operator.personalization", 
  "exp": 1757078311,
  "iat": 1757078011
}
```

**Problems Identified**:
1. **Secret Mismatch**: Rails and Python Operator use different JWT secrets
2. **Validation Logic**: Python Operator has stricter validation requirements
3. **Complexity**: JWT adds unnecessary complexity for internal services
4. **Debugging**: Difficult to troubleshoot authentication issues

### Option 2: STS (Same Trust Store) Communication (Recommended)
**Status**: ✅ **RECOMMENDED** - Simplified internal communication

**Implementation**:
- Remove JWT authentication entirely
- Rely on network-level security (VPC, internal network)
- Use simple request headers for identification

**Benefits**:
- ✅ **Simplified**: No JWT generation/validation complexity
- ✅ **Reliable**: No authentication failures blocking communication
- ✅ **Fast**: Reduced latency (no JWT processing)
- ✅ **Debuggable**: Easy to troubleshoot communication issues
- ✅ **Secure**: Network isolation provides adequate security

### Option 3: Simple API Key (Alternative)
**Status**: 🔄 **ALTERNATIVE** - Lightweight authentication

**Implementation**:
- Use simple API key header: `X-API-Key: your-internal-key`
- Validate key on Python Operator side
- No JWT complexity

## Recommended Implementation Plan

### Phase 1: Remove JWT Authentication (Immediate)

**Rails Backend Changes**:
```ruby
# app/services/personalization/planner_client.rb
def self.build_headers
  {
    "Content-Type" => "application/json",
    "Accept" => "application/json",
    # Remove JWT authentication for STS communication
    # "Authorization" => "Bearer #{generate_jwt_token}",
    "X-Request-Id" => Current.request_id || SecureRandom.uuid,
    "X-Plan-DSL-Version" => "1.0-mvp"
  }
end
```

**Python Operator Changes**:
```python
# Remove JWT validation from /operator/query-pack endpoint
# Accept requests without authentication for internal services
@app.post("/operator/query-pack")
def query_pack():
    # Skip JWT validation for STS communication
    # Process request directly
    pass
```

### Phase 2: Add Request Identification (Optional)

**Enhanced Headers**:
```ruby
{
  "Content-Type" => "application/json",
  "Accept" => "application/json",
  "X-Request-Id" => "uuid-for-tracing",
  "X-Service-Name" => "rails.personalization",
  "X-Plan-DSL-Version" => "1.0-mvp"
}
```

### Phase 3: Network Security (Production)

**Security Measures**:
- VPC isolation for internal services
- Network ACLs restricting access
- Service mesh for encrypted communication
- Monitoring and alerting for unusual traffic

## Security Considerations

### Internal Service Communication
- **Trust Boundary**: Both services run in the same trusted environment
- **Network Isolation**: Services communicate over internal network only
- **No External Access**: Python Operator not exposed to external traffic
- **Monitoring**: All requests logged and monitored

### Risk Assessment
- **Low Risk**: Internal services in trusted environment
- **Mitigation**: Network-level security controls
- **Monitoring**: Request logging and anomaly detection

## Implementation Timeline

### Week 1: Remove JWT Authentication
- [ ] Update Rails `PlannerClient` to remove JWT generation
- [ ] Update Python Operator to skip JWT validation
- [ ] Test end-to-end communication
- [ ] Deploy to development environment

### Week 2: Enhanced Monitoring
- [ ] Add request tracing headers
- [ ] Implement request logging
- [ ] Set up monitoring dashboards
- [ ] Test communication reliability

### Week 3: Production Deployment
- [ ] Deploy to staging environment
- [ ] Load testing without JWT overhead
- [ ] Production deployment
- [ ] Monitor performance improvements

## Testing Strategy

### Communication Tests
```bash
# Test Rails-Operator communication
rails runner lib/test_real_operator_comm.rb

# Test end-to-end personalization flow
rails runner lib/test_end_to_end_flow.rb

# Test API endpoint for frontend
curl -X POST http://localhost:3000/api/demo/personalized_feed \
  -H "Content-Type: application/json" \
  -d '{"page":"home","user_id":1,"region":"ke"}'
```

### Performance Tests
- **Latency**: Measure request/response times without JWT processing
- **Throughput**: Test request rate without authentication overhead
- **Reliability**: Verify communication stability

## Rollback Plan

If issues arise, we can quickly rollback by:
1. Re-enabling JWT authentication in Rails
2. Re-enabling JWT validation in Python Operator
3. Using the existing JWT secret configuration

## Benefits of STS Communication

### Performance Improvements
- **Reduced Latency**: No JWT generation/validation overhead
- **Higher Throughput**: Faster request processing
- **Lower CPU Usage**: No cryptographic operations

### Operational Benefits
- **Simplified Debugging**: No authentication-related issues
- **Easier Testing**: No JWT token management in tests
- **Reduced Complexity**: Simpler codebase maintenance

### Development Benefits
- **Faster Development**: No JWT setup/configuration
- **Easier Integration**: Straightforward service communication
- **Better Testing**: No authentication mocking required

## Conclusion

**Recommendation**: Remove JWT authentication for Rails-Operator communication and implement STS (Same Trust Store) communication.

**Rationale**: 
- JWT adds unnecessary complexity for internal services
- Network-level security provides adequate protection
- Simplified communication improves reliability and performance
- Easier to debug and maintain

**Next Steps**:
1. Implement STS communication (remove JWT)
2. Test end-to-end communication
3. Deploy to development environment
4. Monitor performance improvements

This approach aligns with industry best practices for internal service communication and will significantly improve our system's reliability and performance.

---

**Document Version**: 1.0  
**Date**: September 5, 2025  
**Author**: Rails Backend Team  
**Reviewers**: AI Team, DevOps Team
