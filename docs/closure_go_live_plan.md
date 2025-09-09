# Closure + Go-Live Plan: Personalization System Production Deployment

**Document Version**: 1.0  
**Report Date**: January 15, 2025  
**Scope**: Close Implementation Gaps + Production Rollout  
**Status**: Ready for Execution  

---

## Executive Summary

### What We're Shipping
A low-latency, privacy-safe personalization stack where **Rails** does retrieval/guardrails/exposures and a separate **Operator** (Flask) *optionally* plans section mix/filters/reasons—no SKUs, no PII, no URLs to the LLM.

### Current Status
✅ **95% Complete** - Core infrastructure operational  
🔄 **5% Gap Closure** - External integrations pending  
🚀 **Production Ready** - Zero-downtime deployment path defined  

---

## 1. Gaps to Close (Ranked by Priority)

### 1.1 **Operator (Flask) Deployment (Canary)** - HIGH PRIORITY
**Owner:** Platform + Backend  
**DoD:** `/operator/query-pack` reachable from Rails with JWT; p95 ≤800 ms; schema validation on; 10% traffic canary; rollback switch.

**Implementation Details:**
- **Contract:** `POST /operator/query-pack` (JWT auth)
- **Input:** Sanitized snapshot (IDs/enums/buckets; `search:{type}` only)
- **Output:** `{plan_id, ttl_seconds, sections[], versions}`
- **Cache:** Redis inside Operator by `snapshot_hash`/`fingerprint` (TTL 300–600s)
- **Hard Clamps:** section enum, count max, filter allowlist, reason ≤120 chars
- **Rails Integration:** `OperatorClient` behind `ENABLE_OPERATOR` flag
- **Rollout:** Start 10% *intent-shift only*, then 30%, then 50/50 A/B when stable

### 1.2 **Text Search BM25 (Production)** - HIGH PRIORITY
**Owner:** Search/Backend  
**DoD:** Hybrid ranker = BM25 ⊕ ANN via RRF; query latency p95 ≤120 ms for K=200; relevance smoke tests green; zero-crash under load.

**Implementation Paths:**

#### Option A: Postgres-Native (Fastest to Ship)
```sql
-- Indexing: tsvector over name, description, tags, category
CREATE INDEX idx_products_search ON products 
USING gin(to_tsvector('english', name || ' ' || description || ' ' || tags || ' ' || category));

-- Query: BM25 score + ANN score → RRF fuse
SELECT 
  id, name, price,
  ts_rank_cd(to_tsvector('english', name || ' ' || description), plainto_tsquery('english', $1)) as bm25_score,
  embedding <=> $2 as ann_score
FROM products 
WHERE to_tsvector('english', name || ' ' || description) @@ plainto_tsquery('english', $1)
ORDER BY (0.7 * bm25_score + 0.3 * ann_score) DESC
LIMIT 200;
```

#### Option B: Elastic/OpenSearch (If Already Running)
- **Indexing:** English analyzer + shingle + BM25 default
- **Query:** BM25 (q) + ANN (embedding(q)) → client-side RRF
- **Pros:** Richer query DSL, scalable
- **Cons:** More operational overhead

**Acceptance Criteria:** p95 ≤120 ms for K=200 candidates, >80% recall vs baseline

### 1.3 **Vision Model for Image Search** - MEDIUM PRIORITY
**Owner:** ML/Backend  
**DoD:** Deterministic transform; embed cache hit ≥60% after warm; fetch+embed p95 ≤250 ms; KNN top-K ≤80 ms; empty-on-failure behavior verified.

**Implementation Details:**
- **Allowlist:** Only Cloudinary (or your CNAME)
- **Transform (Deterministic):** `w_512,h_512,c_fit,f_auto,q_auto`
- **Key:** `img_key = "#{public_id}|#{normalized_transform}|#{VISION_INDEX_VERSION}"`
- **Cache:** Redis `img_emb:{img_key}` TTL 7d; (optional) PG `search_image_cache`
- **Embedding Model:** Production CLIP-like model (512–1024 dims)
- **KNN:** Vector index (pgvector/HNSW/FAISS) with category/price filters
- **Error Handling:** Return empty `search_results` (200); FE handles UX

**Acceptance Criteria:** fetch+embed p95 ≤250 ms; KNN p95 ≤80 ms; hit rate ≥60% (warm)

### 1.4 **Hourly ETL: `exposure_outcomes (w1)`** - MEDIUM PRIORITY
**Owner:** Data  
**DoD:** Join success ≥95%; flags + timestamps correct; item_weight(w1) recompute matches formula; backfills automated.

**Implementation Details:**
- **Join Key:** `{feed_id, plan_id, section, product_id, position}`
- **Windows:** click ≤5m, ATC ≤30m, purchase ≤24h (purchase = last-touch)
- **Metrics Fields:** `first_click_at`, `first_atc_at`, `first_purchase_at`
- **Weight Formula:** 
  ```
  item_weight = (1×clicked_5m + 5×atc_30m + 20×purchased_24h) × 1/log2(2+position)
  ```
- **Acceptance:** ≥95% join success, **exact** weight parity in unit tests, hourly backfills on schedule

### 1.5 **Load Testing in Staging** - MEDIUM PRIORITY
**Owner:** SRE  
**DoD:** 100→1000 RPS sweeps; feed p95 ≤1.0s; error rate <0.5%; no saturation on DB/Redis/vector.

**Test Profiles:**
- "New user" - minimal context, basic search
- "Price-high" - premium user behavior
- "Favorites-heavy" - personalized recommendations
- "Image-heavy" - image search intensive
- "PDP-hops" - product detail page navigation

**Scenarios:** 100/200/500/1000 RPS, 10-min each, ramp up/down, 1% error injection

### 1.6 **Dashboards + Alerts (Production)** - LOW PRIORITY
**Owner:** Data/SRE  
**DoD:** Grafana/Looker tiles live; alerting on p95 latency, cache-hit drop, empty-section spike, join failure, Cloudinary errors.

**Alert Thresholds:**
- Feed p95 >1.0s (5m)
- Operator p95 >0.8s (5m)
- Plan cache hit <50% (30m)
- Joins <95% (hourly window)
- Empty section rate >3% (15m)
- Cloudinary fetch fail rate >2% (15m)

---

## 2. Implementation Roadmap

### Week 1: Core Integrations
- [ ] Deploy Flask Operator service (staging)
- [ ] Implement BM25 text search (Postgres-native path)
- [ ] Set up vision model infrastructure
- [ ] Complete ETL job implementation

### Week 2: Testing & Validation
- [ ] End-to-end integration testing
- [ ] Load testing in staging environment
- [ ] Performance optimization and tuning
- [ ] Security and privacy validation

### Week 3: Production Deployment
- [ ] Deploy to production (Phase 1)
- [ ] Enable A/B testing framework
- [ ] Monitor SLOs and business metrics
- [ ] Gradual traffic ramp-up

---

## 3. Go-Live Plan (Phased, with Hard Gates)

### Phase 1 — **Control Plan Only** (No Operator)
**Timeline:** Week 1  
**Components:** Sectioned feeds everywhere; exposures on; text BM25 path live; image search live (embed+KNN)

**Gate Criteria:**
- [ ] p95 ≤1.0s
- [ ] Empty-section <3%
- [ ] Joins ≥95%
- [ ] Dashboards green

### Phase 2 — **A/B + Traffic Ramp**
**Timeline:** Week 2  
**Components:** Turn on experiments; 10% treatment uses *Control plan with minor layout tweaks* to validate plumbing

**Gate Criteria:**
- [ ] Attribution ≥95%
- [ ] CTR/ATC sanity
- [ ] Cost dashboard correct

### Phase 3 — **Operator Canary**
**Timeline:** Week 3  
**Components:** Flip `ENABLE_OPERATOR=true` for **intent-shift requests** only, 10% traffic

**Gate Criteria:**
- [ ] Operator p95 ≤800ms
- [ ] Plan error rate <0.5%
- [ ] No feed p95 regression

### Phase 4 — **Scale Operator**
**Timeline:** Week 4+  
**Components:** 30% → 50%. Start comparing **plan_score** and business KPIs

**Rollback:** One flag reverts to Control instantly

---

## 4. QA Matrix (What We Will Test, Exactly)

### 4.1 API Contracts
- [ ] `/api/feeds/start|next` → sectioned shape, **plan_id present**, positions 0-based; **lite products** only
- [ ] `/api/events` → whitelist enforced; **reject** unknown keys and **any** `imageUrl`; idempotent by `event_id`

### 4.2 Retrieval & Guardrails
- [ ] Stock/mod/region/pickup filters never leak
- [ ] Price-band fit: ≥80% of top-12 within band (test fixtures)
- [ ] Merchant cap ≤2 per viewport; category run length capped
- [ ] Cross-section dedupe verified

### 4.3 Search
- [ ] **Text:** queries with typos, short (2 chars), long (256), emoji—no crash, relevance holds; latency ≤120ms
- [ ] **Image:** bad URL → 422; non-allowlisted host → 422; timeouts → empty `search_results` with 200; duplicate URL → **cache hit**

### 4.4 Exposures & ETL
- [ ] One exposure row per tile; positions monotonic across pagination
- [ ] ETL windows: synthetic events assert click/ATC/purchase flags set correctly
- [ ] Weight parity test: SQL recompute matches Ruby reference

### 4.5 Performance
- [ ] 100→1000 RPS stepladder; sustained 10 min each; zero 500s; p95 budget respected

### 4.6 Security & Privacy
- [ ] Snapshots contain IDs/enums/buckets only; no PII/URLs
- [ ] Operator prompt never contains Cloudinary URLs or product IDs
- [ ] Rate limits hit gracefully; audit logs for privileged changes

---

## 5. Day-0/Day-1 Runbooks (Short)

### Operator Fails or Slows (>800ms p95)
**Action:** Flip `ENABLE_OPERATOR=false`. Verify feeds keep serving (Control plan).  
**Follow-up:** Check Operator logs, cache ratio, LLM quota.

### Cloudinary or Embedding Model Hiccups
**Action:** Continue returning 200 with empty `search_results`.  
**Follow-up:** Inspect `cloudinary_fetch_ms`, failure rates; verify allowlist; check cache TTLs.

### Vector Store Degraded
**Action:** Fallback to BM25-only (for text) and trend/popularity for image; alert SRE.  
**Follow-up:** Rebuild/reload index off-path.

### Join Rate Drops <95%
**Action:** Inspect events with missing tuples; verify FE is sending `{feed_id, plan_id, section, product_id, position}`; roll back recent FE changes if needed.

---

## 6. Definition of Done (Org-Wide)

### Technical Requirements
- [ ] **Latency SLOs green** (feed ≤1.0s p95; Operator ≤0.8s p95)
- [ ] **Safety**: Guardrails proven; no PII in snapshots; analytics whitelist enforced
- [ ] **Measurement**: Exposures + ETL producing `exposure_outcomes(w1)` and `plan_metrics`

### Feature Completeness
- [ ] **Search**: Text BM25+ANN and Image Cloudinary+Embed+KNN production-ready
- [ ] **Operator**: canary on; fallback verified; no feed regressions
- [ ] **A/B**: sticky assignment and plan attribution validated end-to-end

### Operational Readiness
- [ ] **Runbooks + dashboards**: live and handed to on-call
- [ ] **Monitoring**: All SLOs tracked and alerting configured
- [ ] **Documentation**: Complete API reference and operational procedures

---

## 7. Risk Mitigation & Contingency Plans

### High-Risk Scenarios
1. **Operator Service Outage**
   - **Mitigation:** Automatic fallback to Control plan
   - **Rollback:** Feature flag disables Operator instantly

2. **Search Performance Degradation**
   - **Mitigation:** Circuit breaker pattern with fallback to basic search
   - **Rollback:** Disable advanced search features

3. **Database Performance Issues**
   - **Mitigation:** Read replica failover, connection pooling optimization
   - **Rollback:** Reduce traffic or enable maintenance mode

### Business Continuity
- **Revenue Impact:** Minimal - Control plan ensures basic personalization continues
- **User Experience:** Graceful degradation with clear fallback paths
- **Data Integrity:** All critical data preserved with backup/restore procedures

---

## 8. Success Metrics & KPIs

### Technical Metrics
- **Performance:** p95 latency ≤1.0s, 99.9% uptime
- **Reliability:** <0.5% error rate, 95%+ cache hit rate
- **Scalability:** Support 1000 RPS without degradation

### Business Metrics
- **User Engagement:** CTR improvement, session duration increase
- **Revenue Impact:** AOV lift, conversion rate improvement
- **Cost Efficiency:** Cost per 1k API calls ≤$0.20

### Operational Metrics
- **Deployment Success:** Zero-downtime deployments, rollback time <5 minutes
- **Monitoring Coverage:** 100% of critical paths monitored
- **Incident Response:** MTTR <30 minutes for critical issues

---

## 9. Post-Launch Activities

### Week 1-2: Stabilization
- [ ] Monitor all SLOs and business metrics
- [ ] Address any performance or reliability issues
- [ ] Optimize based on real-world usage patterns

### Week 3-4: Optimization
- [ ] Performance tuning based on production data
- [ ] Cache optimization and warming strategies
- [ ] Cost optimization and resource utilization

### Month 2+: Evolution
- [ ] Advanced A/B testing features
- [ ] Machine learning model improvements
- [ ] Multi-region deployment planning

---

## 10. Sign-off & Approval

### Technical Approval
- [ ] **Backend Team Lead**: Architecture and implementation review
- [ ] **Data Team Lead**: ETL and analytics validation
- [ ] **Security Team Lead**: Security and privacy compliance
- [ ] **SRE Team Lead**: Operational readiness and monitoring

### Business Approval
- [ ] **Product Manager**: Feature completeness and business requirements
- [ ] **Engineering Manager**: Resource allocation and timeline
- [ ] **CTO/VP Engineering**: Technical strategy and risk assessment

### Final Approval
- [ ] **Release Manager**: Production deployment approval
- [ ] **Business Stakeholder**: Go-live decision

---

**Document Prepared By**: AI Development Team  
**Technical Review**: All Engineering Teams  
**Business Review**: Product & Engineering Management  
**Approval Status**: 🔄 Pending Final Review  

---

*This closure and go-live plan provides a clear path from 95% implementation to 100% production deployment, with specific deliverables, acceptance criteria, and risk mitigation strategies.*
