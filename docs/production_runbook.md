# Production Runbook
# Personalization System Operations

**Document Version**: 1.0  
**Last Updated**: January 15, 2025  
**Target Audience**: SRE, DevOps, On-Call Engineers  

---

## 🚨 Critical Incidents

### Feed Service Down
**Symptoms**: 
- 500 errors on `/api/feeds/*` endpoints
- High error rates in monitoring
- User complaints about broken feeds

**Immediate Actions**:
1. **Check Application Logs**
   ```bash
   # Check Rails logs
   tail -f log/production.log | grep "feed"
   
   # Check for database connection issues
   tail -f log/production.log | grep "PG::"
   ```

2. **Verify Database Health**
   ```bash
   # Check database connectivity
   bin/rails db:version
   
   # Check connection pool
   bin/rails console
   ActiveRecord::Base.connection_pool.stat
   ```

3. **Check Redis Health**
   ```bash
   # Test Redis connectivity
   redis-cli ping
   
   # Check Redis memory usage
   redis-cli info memory
   ```

4. **Restart Application** (if needed)
   ```bash
   sudo systemctl restart rails
   # or
   sudo systemctl restart puma
   ```

**Escalation**: If unresolved in 15 minutes, escalate to Backend Team Lead

---

### High Latency (>2s P95)
**Symptoms**:
- Feed response times >2s
- User complaints about slow loading
- Monitoring alerts firing

**Immediate Actions**:
1. **Check Database Performance**
   ```bash
   # Check slow queries
   bin/rails console
   ActiveRecord::Base.connection.execute("SELECT * FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;")
   ```

2. **Check Cache Hit Rates**
   ```bash
   # Monitor Redis cache performance
   redis-cli info stats | grep "keyspace_hits\|keyspace_misses"
   ```

3. **Check Vector Search Performance**
   ```bash
   # Check pgvector index health
   bin/rails console
   ActiveRecord::Base.connection.execute("SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch FROM pg_stat_user_indexes WHERE indexname LIKE '%vector%';")
   ```

4. **Scale Resources** (if needed)
   ```bash
   # Increase database connections
   # Scale application instances
   # Add Redis read replicas
   ```

**Escalation**: If P95 >5s for 10+ minutes, escalate to SRE Lead

---

### Search Service Degraded
**Symptoms**:
- Text search returning irrelevant results
- Image search failing or slow
- High search error rates

**Immediate Actions**:
1. **Check BM25 Indexes**
   ```bash
   bin/rails console
   # Verify tsvector indexes exist
   ActiveRecord::Base.connection.execute("SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'products' AND indexname LIKE '%bm25%';")
   ```

2. **Check Vector Indexes**
   ```bash
   # Verify pgvector extension
   ActiveRecord::Base.connection.execute("SELECT * FROM pg_extension WHERE extname = 'vector';")
   
   # Check HNSW index health
   ActiveRecord::Base.connection.execute("SELECT schemaname, tablename, indexname, idx_scan FROM pg_stat_user_indexes WHERE indexname LIKE '%hnsw%';")
   ```

3. **Validate Search Results**
   ```bash
   # Test search endpoints manually
   curl -X POST http://localhost:3000/api/feeds/start \
     -H "Content-Type: application/json" \
     -d '{"session_id":"test","page":"home","searchType":"text","searchTerm":"test"}'
   ```

4. **Rebuild Indexes** (if corrupted)
   ```bash
   # Rebuild BM25 indexes
   bin/rails console
   ActiveRecord::Base.connection.execute("REINDEX INDEX CONCURRENTLY idx_products_bm25_search;")
   
   # Rebuild vector indexes
   ActiveRecord::Base.connection.execute("REINDEX INDEX CONCURRENTLY idx_product_embeddings_hnsw;")
   ```

**Escalation**: If search completely broken for 30+ minutes, escalate to ML Team

---

## 🔧 Routine Maintenance

### Daily Health Checks
**Time**: 9:00 AM UTC

**Checklist**:
- [ ] **Application Health**
  - [ ] All health check endpoints responding
  - [ ] Error rates < 0.5%
  - [ ] Response times within SLO

- [ ] **Database Health**
  - [ ] Connection pool healthy
  - [ ] No long-running queries
  - [ ] Index usage statistics normal

- [ ] **Cache Performance**
  - [ ] Redis memory usage <80%
  - [ ] Cache hit rates >60%
  - [ ] No connection timeouts

- [ ] **ETL Jobs**
  - [ ] `DailyMetricsRollupJob` completed successfully
  - [ ] `ExposureOutcomesJob` completed successfully
  - [ ] Join success rates >95%

**Commands**:
```bash
# Check application health
curl -f http://localhost:3000/health

# Check database connections
bin/rails console
ActiveRecord::Base.connection_pool.stat

# Check Redis status
redis-cli info memory
redis-cli info stats

# Check ETL job status
bin/rails console
Personalization::ExposureOutcomesJob.last_run_status
```

---

### Weekly Performance Review
**Time**: Every Monday 10:00 AM UTC

**Metrics to Review**:
- [ ] **Performance Trends**
  - [ ] P95 latency trends (7 days)
  - [ ] Cache hit rate trends
  - [ ] Error rate trends
  - [ ] Database query performance

- [ ] **Business Metrics**
  - [ ] Feed engagement rates
  - [ ] Search conversion rates
  - [ ] User satisfaction scores
  - [ ] A/B test results

- [ ] **Infrastructure Health**
  - [ ] Resource utilization trends
  - [ ] Database growth patterns
  - [ ] Cache memory usage trends
  - [ ] Index performance metrics

**Actions**:
- [ ] Identify performance bottlenecks
- [ ] Plan optimization tasks
- [ ] Update capacity planning
- [ ] Document lessons learned

---

### Monthly Capacity Planning
**Time**: First Monday of each month

**Review Items**:
- [ ] **Current Usage**
  - [ ] Peak RPS trends
  - [ ] Database growth rate
  - [ ] Cache memory growth
  - [ ] Storage growth rate

- [ ] **Projected Growth**
  - [ ] User growth projections
  - [ ] Feature launch impact
  - [ ] Seasonal traffic patterns
  - [ ] Business expansion plans

- [ ] **Resource Planning**
  - [ ] Database scaling needs
  - [ ] Cache scaling needs
  - [ ] Application scaling needs
  - [ ] Infrastructure upgrades

---

## 📊 Monitoring & Alerting

### Key Metrics to Watch
**Application Metrics**:
- `feed_requests_total` - Total feed requests
- `feed_request_duration_seconds` - Response time histogram
- `feed_cache_hit_ratio` - Cache performance
- `feed_empty_section_ratio` - Content quality

**Search Metrics**:
- `search_requests_total` - Search volume
- `search_duration_seconds` - Search performance
- `search_cache_hit_ratio` - Search cache performance
- `search_results_count` - Result quality

**Infrastructure Metrics**:
- `database_connections_active` - Database load
- `redis_memory_usage_bytes` - Cache memory usage
- `vector_index_scan_count` - Vector search usage
- `etl_job_duration_seconds` - ETL performance

### Alert Thresholds
**Critical Alerts** (Immediate Response):
- Feed P95 latency >2.0s for 2+ minutes
- Error rate >2% for 5+ minutes
- Database connection pool >90% full
- Redis memory usage >90%

**Warning Alerts** (Investigate within 30 minutes):
- Feed P95 latency >1.2s for 5+ minutes
- Error rate >1% for 10+ minutes
- Cache hit rate <50% for 15+ minutes
- ETL job failures for 2+ consecutive runs

**Info Alerts** (Monitor and log):
- Empty section rate >5%
- Search performance degradation
- Cache memory usage >80%
- Database slow query increase

---

## 🛠️ Troubleshooting Commands

### Database Troubleshooting
```bash
# Check database status
bin/rails db:version
bin/rails db:environment

# Check connection pool
bin/rails console
ActiveRecord::Base.connection_pool.stat

# Check slow queries
ActiveRecord::Base.connection.execute("
  SELECT query, calls, total_time, mean_time, rows 
  FROM pg_stat_statements 
  ORDER BY mean_time DESC 
  LIMIT 10;
")

# Check table sizes
ActiveRecord::Base.connection.execute("
  SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
  FROM pg_tables 
  WHERE schemaname = 'public'
  ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
")

# Check index usage
ActiveRecord::Base.connection.execute("
  SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
  FROM pg_stat_user_indexes
  ORDER BY idx_scan DESC;
")
```

### Redis Troubleshooting
```bash
# Check Redis status
redis-cli ping
redis-cli info server

# Check memory usage
redis-cli info memory
redis-cli memory usage

# Check cache keys
redis-cli keys "feed:*" | wc -l
redis-cli keys "plan:*" | wc -l

# Check cache performance
redis-cli info stats | grep -E "(keyspace_hits|keyspace_misses|hit_rate)"

# Monitor Redis in real-time
redis-cli monitor
```

### Application Troubleshooting
```bash
# Check application logs
tail -f log/production.log | grep "feed"
tail -f log/production.log | grep "search"
tail -f log/production.log | grep "error"

# Check process status
ps aux | grep puma
ps aux | grep sidekiq

# Check application health
curl -f http://localhost:3000/health
curl -f http://localhost:3000/api/feeds/start

# Check environment variables
bin/rails console
ENV['ENABLE_OPERATOR']
ENV['CLOUDINARY_HOST_ALLOWLIST']
```

---

## 📚 Common Issues & Solutions

### Issue: High Database Connection Usage
**Symptoms**: Database connection pool exhausted, connection timeouts

**Causes**:
- Long-running queries
- Connection leaks
- High concurrent load
- Database performance issues

**Solutions**:
1. **Immediate**: Restart application to clear connections
2. **Short-term**: Increase connection pool size
3. **Long-term**: Optimize queries, add read replicas

**Commands**:
```bash
# Check connection usage
bin/rails console
ActiveRecord::Base.connection_pool.stat

# Check for long-running queries
ActiveRecord::Base.connection.execute("
  SELECT pid, now() - pg_stat_activity.query_start AS duration, query
  FROM pg_stat_activity
  WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';
")

# Kill long-running queries (if needed)
SELECT pg_terminate_backend(pid) FROM pg_stat_activity 
WHERE (now() - pg_stat_activity.query_start) > interval '10 minutes';
```

### Issue: Redis Memory Exhaustion
**Symptoms**: Redis out of memory errors, cache misses increasing

**Causes**:
- Large cache objects
- Memory leaks
- Insufficient memory allocation
- No eviction policy

**Solutions**:
1. **Immediate**: Increase Redis memory limit
2. **Short-term**: Clear old cache keys
3. **Long-term**: Implement proper eviction policies

**Commands**:
```bash
# Check memory usage
redis-cli info memory

# Clear old cache keys
redis-cli --scan --pattern "feed:*" | xargs redis-cli del
redis-cli --scan --pattern "plan:*" | xargs redis-cli del

# Set memory policy
redis-cli config set maxmemory-policy allkeys-lru
```

### Issue: Vector Search Performance Degradation
**Symptoms**: Image search slow, high latency on vector operations

**Causes**:
- Index fragmentation
- Insufficient memory for vector operations
- High concurrent vector searches
- Index corruption

**Solutions**:
1. **Immediate**: Rebuild vector indexes
2. **Short-term**: Optimize vector search queries
3. **Long-term**: Scale vector database resources

**Commands**:
```bash
# Check index health
bin/rails console
ActiveRecord::Base.connection.execute("
  SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read
  FROM pg_stat_user_indexes 
  WHERE indexname LIKE '%hnsw%';
")

# Rebuild indexes
ActiveRecord::Base.connection.execute("REINDEX INDEX CONCURRENTLY idx_product_embeddings_hnsw;")

# Check vector extension
ActiveRecord::Base.connection.execute("SELECT * FROM pg_extension WHERE extname = 'vector';")
```

---

## 🚀 Deployment Procedures

### Rolling Deployment
**Pre-deployment**:
- [ ] Run load tests in staging
- [ ] Validate all migrations
- [ ] Check feature flags
- [ ] Notify stakeholders

**Deployment Steps**:
1. **Deploy to 25% of instances**
   ```bash
   # Update application code
   git pull origin main
   bundle install
   bin/rails db:migrate
   sudo systemctl restart rails
   ```

2. **Monitor for 5 minutes**
   - Check error rates
   - Monitor response times
   - Verify functionality

3. **Deploy to 50% of instances**
4. **Monitor for 5 minutes**
5. **Deploy to 100% of instances**

**Post-deployment**:
- [ ] Monitor all metrics for 30 minutes
- [ ] Validate business functionality
- [ ] Check performance impact
- [ ] Document deployment results

### Rollback Procedure
**Immediate Rollback**:
```bash
# Revert to previous version
git checkout <previous_tag>
bundle install
sudo systemctl restart rails

# Verify rollback
curl -f http://localhost:3000/health
```

**Full Rollback**:
```bash
# Revert code and database
git checkout <previous_tag>
bin/rails db:rollback STEP=<number_of_migrations>
sudo systemctl restart rails

# Validate complete rollback
bin/rails routes
bin/rails db:version
```

---

## 📞 Escalation Procedures

### Escalation Matrix
**Level 1 (On-Call Engineer)**:
- Response time: 5 minutes
- Handle: Basic troubleshooting, restarts, monitoring

**Level 2 (SRE Engineer)**:
- Response time: 15 minutes
- Handle: Complex issues, performance optimization, scaling

**Level 3 (Backend Team Lead)**:
- Response time: 30 minutes
- Handle: Architecture issues, major bugs, business impact

**Level 4 (Engineering Manager)**:
- Response time: 1 hour
- Handle: System-wide issues, business continuity

### Escalation Triggers
**Escalate to Level 2**:
- Issue unresolved after 15 minutes
- Performance degradation >50%
- Multiple services affected
- Business impact detected

**Escalate to Level 3**:
- Issue unresolved after 30 minutes
- System unavailable
- Data integrity concerns
- Security incidents

**Escalate to Level 4**:
- Issue unresolved after 1 hour
- Business operations impacted
- Customer data at risk
- Regulatory compliance issues

---

## 📋 Contact Information

**On-Call Rotation**:
- **Primary**: [Name] - [Phone] - [Slack]
- **Secondary**: [Name] - [Phone] - [Slack]
- **Escalation**: [Name] - [Phone] - [Slack]

**Team Contacts**:
- **SRE Lead**: [Name] - [Phone] - [Slack]
- **Backend Lead**: [Name] - [Phone] - [Slack]
- **Data Lead**: [Name] - [Phone] - [Slack]
- **Product Manager**: [Name] - [Phone] - [Slack]

**External Contacts**:
- **Cloud Provider**: [Support URL] - [Phone]
- **Database Vendor**: [Support URL] - [Phone]
- **Monitoring Vendor**: [Support URL] - [Phone]

---

**Document Owner**: SRE Team  
**Last Review**: [Date]  
**Next Review**: [Date]  
**Approved By**: [Name]
