# Implementation Checklist: Closing the 5% Gap

**Document Version**: 1.0  
**Report Date**: January 15, 2025  
**Scope**: Gap Closure Implementation Tracking  
**Status**: Ready for Team Execution  

---

## Overview

This checklist tracks the implementation of the remaining 5% of features needed to complete the personalization system. Each item includes specific deliverables, acceptance criteria, and owner assignments.

---

## 1. Operator (Flask) Deployment - HIGH PRIORITY

### 1.1 Flask Service Implementation
**Owner:** Platform + Backend  
**Timeline:** Week 1  
**Status:** 🔄 In Progress  

#### Core Service
- [ ] Create Flask application with `/operator/query-pack` endpoint
- [ ] Implement JWT authentication middleware
- [ ] Add input validation for sanitized snapshots
- [ ] Implement output schema validation
- [ ] Add Redis caching layer (TTL 300-600s)
- [ ] Add logging and monitoring

#### Contract Implementation
- [ ] Accept sanitized snapshot (IDs/enums/buckets only)
- [ ] Return `{plan_id, ttl_seconds, sections[], versions}`
- [ ] Implement hard clamps for section enum, count max, filter allowlist
- [ ] Limit reason field to ≤120 characters
- [ ] Add schema validation for all inputs/outputs

#### Performance & Reliability
- [ ] Achieve p95 ≤800ms response time
- [ ] Implement circuit breaker pattern
- [ ] Add timeout handling (default 800ms)
- [ ] Implement graceful degradation
- [ ] Add health check endpoint

#### Rails Integration
- [ ] Complete `OperatorClient` implementation
- [ ] Add `ENABLE_OPERATOR` feature flag
- [ ] Implement fallback to Control plan on failure
- [ ] Add metrics collection for Operator calls
- [ ] Test integration end-to-end

**Acceptance Criteria:**
- [ ] `/operator/query-pack` reachable from Rails with JWT
- [ ] p95 ≤800ms response time
- [ ] Schema validation working
- [ ] 10% traffic canary ready
- [ ] Rollback switch functional

---

## 2. Text Search BM25 Implementation - HIGH PRIORITY

### 2.1 Postgres-Native Implementation (Recommended Path)
**Owner:** Search/Backend  
**Timeline:** Week 1  
**Status:** 🔄 In Progress  

#### Database Setup
- [ ] Create tsvector index on products table
- [ ] Add pg_trgm extension for fuzzy matching
- [ ] Create composite index for performance
- [ ] Add search-specific columns if needed

#### Index Creation
```sql
-- Execute this SQL
CREATE INDEX idx_products_search ON products 
USING gin(to_tsvector('english', name || ' ' || description || ' ' || tags || ' ' || category));

CREATE INDEX idx_products_trgm ON products 
USING gin(name gin_trgm_ops, description gin_trgm_ops);
```

#### Search Service Implementation
- [ ] Create `SearchTextRetriever` service
- [ ] Implement BM25 scoring using `ts_rank_cd`
- [ ] Integrate with existing vector search
- [ ] Implement RRF (Reciprocal Rank Fusion) for hybrid ranking
- [ ] Add query normalization (lowercase, trim, stop words)

#### Query Implementation
```ruby
# Example implementation in SearchTextRetriever
def search(query, limit: 200)
  normalized_query = normalize_query(query)
  embedding = get_query_embedding(normalized_query)
  
  results = execute_hybrid_search(normalized_query, embedding, limit)
  apply_guardrails(results)
end

private

def execute_hybrid_search(query, embedding, limit)
  sql = <<-SQL
    SELECT 
      id, name, price,
      ts_rank_cd(to_tsvector('english', name || ' ' || description), plainto_tsquery('english', $1)) as bm25_score,
      embedding <=> $2 as ann_score
    FROM products 
    WHERE to_tsvector('english', name || ' ' || description) @@ plainto_tsquery('english', $1)
    ORDER BY (0.7 * bm25_score + 0.3 * ann_score) DESC
    LIMIT $3
  SQL
  
  ActiveRecord::Base.connection.exec_query(sql, 'Search', [query, embedding, limit])
end
```

#### Performance Optimization
- [ ] Achieve p95 ≤120ms for K=200 candidates
- [ ] Add query result caching
- [ ] Optimize database queries
- [ ] Add performance monitoring

**Acceptance Criteria:**
- [ ] Hybrid ranker = BM25 ⊕ ANN via RRF
- [ ] Query latency p95 ≤120ms for K=200
- [ ] Relevance smoke tests green
- [ ] Zero-crash under load

---

## 3. Vision Model for Image Search - MEDIUM PRIORITY

### 3.1 Infrastructure Setup
**Owner:** ML/Backend  
**Timeline:** Week 1-2  
**Status:** 🔄 In Progress  

#### Model Selection & Deployment
- [ ] Select production CLIP-like model (512-1024 dims)
- [ ] Deploy model to production environment
- [ ] Set up model versioning system
- [ ] Add model health monitoring

#### Cloudinary Integration
- [ ] Implement URL allowlist validation
- [ ] Create deterministic transform normalization
- [ ] Implement `w_512,h_512,c_fit,f_auto,q_auto` transform
- [ ] Add URL validation tests

#### Caching Layer
- [ ] Implement Redis caching with TTL 7d
- [ ] Create cache key format: `img_key = "#{public_id}|#{normalized_transform}|#{VISION_INDEX_VERSION}"`
- [ ] Add cache hit/miss monitoring
- [ ] Implement cache warming strategy

#### Embedding Pipeline
- [ ] Implement image fetching with timeout (≤800ms)
- [ ] Add size validation (≤5MB)
- [ ] Implement embedding generation
- [ ] Add error handling for failed fetches

#### Vector Search
- [ ] Implement KNN search using pgvector
- [ ] Add category/price filters
- [ ] Optimize for ≤80ms response time
- [ ] Add fallback to popularity-based results

**Acceptance Criteria:**
- [ ] Deterministic transform working
- [ ] Embed cache hit ≥60% after warm
- [ ] Fetch+embed p95 ≤250ms
- [ ] KNN top-K ≤80ms
- [ ] Empty-on-failure behavior verified

---

## 4. Hourly ETL: exposure_outcomes (w1) - MEDIUM PRIORITY

### 4.1 ETL Job Implementation
**Owner:** Data  
**Timeline:** Week 1  
**Status:** 🔄 In Progress  

#### Job Structure
- [ ] Create `ExposureOutcomesJob` class
- [ ] Implement hourly execution schedule
- [ ] Add job monitoring and alerting
- [ ] Implement retry logic for failures

#### Join Logic Implementation
- [ ] Implement join by `{feed_id, plan_id, section, product_id, position}`
- [ ] Add window-based attribution logic:
  - Click ≤5m window
  - ATC ≤30m window  
  - Purchase ≤24h window (last-touch)
- [ ] Add timestamp validation
- [ ] Implement data quality checks

#### Metrics Calculation
- [ ] Implement `item_weight(w1)` formula:
  ```
  item_weight = (1×clicked_5m + 5×atc_30m + 20×purchased_24h) × 1/log2(2+position)
  ```
- [ ] Add position discount calculation
- [ ] Implement weight validation
- [ ] Add unit tests for formula accuracy

#### Data Fields
- [ ] Add `first_click_at` timestamp
- [ ] Add `first_atc_at` timestamp
- [ ] Add `first_purchase_at` timestamp
- [ ] Add `item_weight` field
- [ ] Add `attribution_flags` (clicked, atc, purchased)

#### Backfill & Monitoring
- [ ] Implement automated backfills
- [ ] Add join success rate monitoring
- [ ] Add data quality alerts
- [ ] Implement performance monitoring

**Acceptance Criteria:**
- [ ] Join success ≥95%
- [ ] Flags + timestamps correct
- [ ] item_weight(w1) recompute matches formula
- [ ] Backfills automated

---

## 5. Load Testing in Staging - MEDIUM PRIORITY

### 5.1 Test Environment Setup
**Owner:** SRE  
**Timeline:** Week 2  
**Status:** 🔄 In Progress  

#### Infrastructure Preparation
- [ ] Set up staging environment with production-like data
- [ ] Configure monitoring and alerting
- [ ] Set up load testing tools (k6/Locust)
- [ ] Prepare test data sets

#### Test Profile Creation
- [ ] "New user" - minimal context, basic search
- [ ] "Price-high" - premium user behavior
- [ ] "Favorites-heavy" - personalized recommendations
- [ ] "Image-heavy" - image search intensive
- [ ] "PDP-hops" - product detail page navigation

#### Load Test Scenarios
- [ ] 100 RPS sustained for 10 minutes
- [ ] 200 RPS sustained for 10 minutes
- [ ] 500 RPS sustained for 10 minutes
- [ ] 1000 RPS sustained for 10 minutes
- [ ] Ramp up/down scenarios
- [ ] 1% error injection tests

#### Performance Validation
- [ ] Feed p95 ≤1.0s under all load levels
- [ ] Error rate <0.5% under all load levels
- [ ] No saturation on DB/Redis/vector
- [ ] Memory usage within acceptable limits
- [ ] CPU usage under 70% threshold

**Acceptance Criteria:**
- [ ] 100→1000 RPS sweeps completed
- [ ] Feed p95 ≤1.0s maintained
- [ ] Error rate <0.5% maintained
- [ ] No saturation on infrastructure

---

## 6. Dashboards + Alerts (Production) - LOW PRIORITY

### 6.1 Dashboard Implementation
**Owner:** Data/SRE  
**Timeline:** Week 2-3  
**Status:** 🔄 In Progress  

#### Core Dashboards
- [ ] Performance dashboard (latency, throughput, errors)
- [ ] Business metrics dashboard (CTR, AOV, conversion)
- [ ] Infrastructure dashboard (CPU, memory, disk)
- [ ] A/B testing dashboard (experiment results)

#### Alert Configuration
- [ ] Feed p95 >1.0s (5m window)
- [ ] Operator p95 >0.8s (5m window)
- [ ] Plan cache hit <50% (30m window)
- [ ] Joins <95% (hourly window)
- [ ] Empty section rate >3% (15m window)
- [ ] Cloudinary fetch fail rate >2% (15m window)

#### Monitoring Integration
- [ ] Integrate with PagerDuty/Slack
- [ ] Set up escalation procedures
- [ ] Configure alert thresholds
- [ ] Add alert documentation

**Acceptance Criteria:**
- [ ] Grafana/Looker tiles live
- [ ] Alerting configured for all thresholds
- [ ] Escalation procedures documented
- [ ] Dashboard access granted to on-call

---

## 7. Integration Testing & Validation

### 7.1 End-to-End Testing
**Owner:** All Teams  
**Timeline:** Week 2  
**Status:** 🔄 In Progress  

#### API Contract Validation
- [ ] `/api/feeds/start|next` returns correct format
- [ ] `/api/events` enforces whitelist correctly
- [ ] All endpoints handle errors gracefully
- [ ] Response schemas validated

#### Search Functionality
- [ ] Text search with various query types
- [ ] Image search with different image formats
- [ ] Error handling for invalid inputs
- [ ] Performance under load

#### A/B Testing Validation
- [ ] User assignment consistency
- [ ] Variant tracking accuracy
- [ ] Attribution pipeline working
- [ ] Experiment management functional

#### Performance Validation
- [ ] Latency SLOs met under load
- [ ] Cache hit rates acceptable
- [ ] Database performance stable
- [ ] No memory leaks or resource exhaustion

---

## 8. Production Deployment Preparation

### 8.1 Deployment Checklist
**Owner:** SRE + Release Manager  
**Timeline:** Week 3  
**Status:** 🔄 In Progress  

#### Infrastructure Readiness
- [ ] Production environment prepared
- [ ] Database migrations tested
- [ ] Monitoring configured
- [ ] Backup procedures verified

#### Application Readiness
- [ ] All features tested in staging
- [ ] Performance benchmarks met
- [ ] Security review completed
- [ ] Documentation updated

#### Rollback Procedures
- [ ] Rollback scripts prepared
- [ ] Feature flags configured
- [ ] Database rollback procedures
- [ ] Communication plan ready

#### Go-Live Approval
- [ ] Technical team approval
- [ ] Business stakeholder approval
- [ ] Release manager approval
- [ ] Final deployment authorization

---

## 9. Post-Deployment Activities

### 9.1 Week 1-2: Stabilization
**Owner:** All Teams  
**Timeline:** Post-Deployment  
**Status:** 🔄 Pending  

- [ ] Monitor all SLOs and business metrics
- [ ] Address any performance or reliability issues
- [ ] Optimize based on real-world usage patterns
- [ ] Document lessons learned

### 9.2 Week 3-4: Optimization
**Owner:** All Teams  
**Timeline:** Post-Deployment  
**Status:** 🔄 Pending  

- [ ] Performance tuning based on production data
- [ ] Cache optimization and warming strategies
- [ ] Cost optimization and resource utilization
- [ ] Advanced monitoring and alerting

### 9.3 Month 2+: Evolution
**Owner:** Product + Engineering  
**Timeline:** Post-Deployment  
**Status:** 🔄 Pending  

- [ ] Advanced A/B testing features
- [ ] Machine learning model improvements
- [ ] Multi-region deployment planning
- [ ] Feature roadmap planning

---

## 10. Final Validation & Sign-off

### 10.1 Definition of Done Validation
**Owner:** All Teams  
**Timeline:** Week 3  
**Status:** 🔄 Pending  

#### Technical Requirements
- [ ] Latency SLOs green (feed ≤1.0s p95; Operator ≤0.8s p95)
- [ ] Safety: Guardrails proven; no PII in snapshots; analytics whitelist enforced
- [ ] Measurement: Exposures + ETL producing exposure_outcomes(w1) and plan_metrics

#### Feature Completeness
- [ ] Search: Text BM25+ANN and Image Cloudinary+Embed+KNN production-ready
- [ ] Operator: canary on; fallback verified; no feed regressions
- [ ] A/B: sticky assignment and plan attribution validated end-to-end

#### Operational Readiness
- [ ] Runbooks + dashboards: live and handed to on-call
- [ ] Monitoring: All SLOs tracked and alerting configured
- [ ] Documentation: Complete API reference and operational procedures

---

## Progress Tracking

### Overall Progress
- **Week 1 Target:** 60% complete
- **Week 2 Target:** 85% complete  
- **Week 3 Target:** 100% complete

### Team Status Updates
**Update this section weekly with current progress:**

#### Week 1 Status (Date: ________)
- [ ] Operator (Flask) deployment: ___% complete
- [ ] Text search BM25: ___% complete
- [ ] Vision model setup: ___% complete
- [ ] ETL implementation: ___% complete

#### Week 2 Status (Date: ________)
- [ ] Load testing: ___% complete
- [ ] Dashboards + alerts: ___% complete
- [ ] Integration testing: ___% complete
- [ ] Performance validation: ___% complete

#### Week 3 Status (Date: ________)
- [ ] Production deployment: ___% complete
- [ ] Go-live validation: ___% complete
- [ ] Final sign-off: ___% complete

---

**Document Owner:** AI Development Team  
**Last Updated:** January 15, 2025  
**Next Review:** Weekly team sync  

---

*Use this checklist to track progress on closing the 5% implementation gap. Update status and progress weekly during team sync meetings.*
