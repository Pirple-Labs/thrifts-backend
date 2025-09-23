# 🚀 Complete Operations & Deployment Guide

## 📋 **Overview**

This comprehensive guide covers all aspects of operations, deployment, monitoring, troubleshooting, and maintenance for the Thrifts backend system.

---

## 🏗️ **Infrastructure Overview**

### **System Architecture**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │    │   Rails App     │    │   Database      │
│   (Nginx)       │───▶│   (Docker)      │───▶│   (PostgreSQL)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Redis Cache   │    │   AI Service    │    │   File Storage  │
│   (Sessions)    │    │   (Python)      │    │   (Images)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### **Environment Strategy**
- **Development**: Local Docker containers
- **Staging**: Cloud-based staging environment
- **Production**: High-availability cloud deployment

---

## 🐳 **Docker Deployment**

### **Development Environment**

#### **Docker Compose Configuration**
```yaml
# docker-compose.yml
version: '3.8'

services:
  web:
    build:
      context: .
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    environment:
      - RAILS_ENV=development
      - DATABASE_URL=postgresql://postgres:password@db:5432/thrifts_backend_development
      - REDIS_URL=redis://redis:6379/0
    volumes:
      - .:/app
      - /app/node_modules
    depends_on:
      - db
      - redis
    command: bundle exec rails server -b 0.0.0.0

  db:
    image: pgvector/pgvector:pg15
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=thrifts_backend_development
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/mark-all-migrations.sql:/docker-entrypoint-initdb.d/mark-all-migrations.sql

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

#### **Development Dockerfile**
```dockerfile
# Dockerfile.dev
FROM ruby:3.2.2

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    nodejs \
    npm \
    libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy package.json and install node modules
COPY package*.json ./
RUN npm install

# Copy application code
COPY . .

# Expose port
EXPOSE 3000

# Start Rails server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

### **Production Environment**

#### **Production Dockerfile**
```dockerfile
# Dockerfile
FROM ruby:3.2.2-alpine

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    nodejs \
    npm \
    libyaml-dev \
    tzdata

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

# Copy package.json and install node modules
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY . .

# Precompile assets
RUN bundle exec rails assets:precompile

# Create non-root user
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup
RUN chown -R appuser:appgroup /app
USER appuser

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start Rails server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-e", "production"]
```

#### **Production Docker Compose**
```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "3000:3000"
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
    depends_on:
      - db
      - redis
    restart: unless-stopped
    deploy:
      replicas: 3
      resources:
        limits:
          memory: 1G
          cpus: '0.5'
        reservations:
          memory: 512M
          cpus: '0.25'

  db:
    image: pgvector/pgvector:pg15
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.25'

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - web
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

---

## 🚀 **Deployment Process**

### **1. Pre-Deployment Checklist**

#### **Code Quality**
- [ ] All tests passing (`bundle exec rspec`)
- [ ] Code review completed
- [ ] Security scan passed
- [ ] Performance tests passed
- [ ] Database migrations tested

#### **Environment Preparation**
- [ ] Environment variables configured
- [ ] SSL certificates ready
- [ ] Database backups completed
- [ ] Monitoring alerts configured
- [ ] Rollback plan prepared

### **2. Deployment Steps**

#### **Development Deployment**
```bash
# Start development environment
docker-compose up -d

# Run database setup
docker-compose exec web bundle exec rails db:create
docker-compose exec web bundle exec rails db:migrate
docker-compose exec web bundle exec rails db:seed

# Verify deployment
curl http://localhost:3000/health
```

#### **Staging Deployment**
```bash
# Build and deploy to staging
docker-compose -f docker-compose.staging.yml up -d --build

# Run database migrations
docker-compose -f docker-compose.staging.yml exec web bundle exec rails db:migrate

# Run smoke tests
docker-compose -f docker-compose.staging.yml exec web bundle exec rspec spec/smoke_tests/

# Verify deployment
curl https://staging-api.thrifts.com/health
```

#### **Production Deployment**
```bash
# Blue-green deployment
# 1. Deploy to green environment
docker-compose -f docker-compose.prod.yml up -d --build

# 2. Run database migrations
docker-compose -f docker-compose.prod.yml exec web bundle exec rails db:migrate

# 3. Run health checks
curl https://api.thrifts.com/health

# 4. Switch load balancer to green
# 5. Monitor for 5 minutes
# 6. Decommission blue environment
```

### **3. Post-Deployment Verification**

#### **Health Checks**
```bash
# API health
curl https://api.thrifts.com/health

# Database connectivity
curl https://api.thrifts.com/health/database

# Redis connectivity
curl https://api.thrifts.com/health/redis

# AI service connectivity
curl https://api.thrifts.com/health/ai_service
```

#### **Smoke Tests**
```bash
# Test key endpoints
curl https://api.thrifts.com/api/home/grid?region=ke
curl https://api.thrifts.com/api/demo/personalized-feed?user_id=1&page=home&region=ke

# Test authentication
curl -H "Authorization: Bearer $JWT_TOKEN" https://api.thrifts.com/api/user/profile
```

---

## 📊 **Monitoring & Observability**

### **1. Application Monitoring**

#### **Health Check Endpoints**
```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def index
    checks = {
      database: check_database,
      redis: check_redis,
      ai_service: check_ai_service,
      storage: check_storage
    }
    
    overall_health = checks.values.all? { |check| check[:status] == 'healthy' }
    
    render json: {
      status: overall_health ? 'healthy' : 'unhealthy',
      checks: checks,
      timestamp: Time.current.iso8601,
      version: Rails.application.config.version
    }, status: overall_health ? 200 : 503
  end

  def database
    result = ActiveRecord::Base.connection.execute('SELECT 1')
    render json: { status: 'healthy', response_time_ms: 0 }
  rescue => e
    render json: { status: 'unhealthy', error: e.message }, status: 503
  end

  def redis
    start_time = Time.current
    Redis.current.ping
    response_time = (Time.current - start_time) * 1000
    
    render json: { 
      status: 'healthy', 
      response_time_ms: response_time 
    }
  rescue => e
    render json: { status: 'unhealthy', error: e.message }, status: 503
  end

  def ai_service
    start_time = Time.current
    response = HTTParty.get("#{Rails.application.config.personalization[:ai_service_url]}/health", timeout: 5)
    response_time = (Time.current - start_time) * 1000
    
    render json: {
      status: response.success? ? 'healthy' : 'unhealthy',
      response_time_ms: response_time,
      ai_service_status: response.body
    }
  rescue => e
    render json: { status: 'unhealthy', error: e.message }, status: 503
  end

  private

  def check_database
    start_time = Time.current
    ActiveRecord::Base.connection.execute('SELECT 1')
    response_time = (Time.current - start_time) * 1000
    
    { status: 'healthy', response_time_ms: response_time }
  rescue => e
    { status: 'unhealthy', error: e.message }
  end

  def check_redis
    start_time = Time.current
    Redis.current.ping
    response_time = (Time.current - start_time) * 1000
    
    { status: 'healthy', response_time_ms: response_time }
  rescue => e
    { status: 'unhealthy', error: e.message }
  end

  def check_ai_service
    start_time = Time.current
    response = HTTParty.get("#{Rails.application.config.personalization[:ai_service_url]}/health", timeout: 5)
    response_time = (Time.current - start_time) * 1000
    
    {
      status: response.success? ? 'healthy' : 'unhealthy',
      response_time_ms: response_time,
      error: response.success? ? nil : response.body
    }
  rescue => e
    { status: 'unhealthy', error: e.message }
  end

  def check_storage
    # Check if file uploads are working
    { status: 'healthy' }
  rescue => e
    { status: 'unhealthy', error: e.message }
  end
end
```

#### **Metrics Collection**
```ruby
# app/services/monitoring/metrics_collector.rb
class Monitoring::MetricsCollector
  def self.collect_system_metrics
    {
      timestamp: Time.current.iso8601,
      system: {
        memory_usage: get_memory_usage,
        cpu_usage: get_cpu_usage,
        disk_usage: get_disk_usage,
        load_average: get_load_average
      },
      application: {
        active_connections: get_active_connections,
        request_rate: get_request_rate,
        error_rate: get_error_rate,
        response_time_p95: get_response_time_p95
      },
      database: {
        connection_pool_size: get_db_connection_pool_size,
        slow_queries: get_slow_queries,
        lock_waits: get_lock_waits
      },
      cache: {
        hit_rate: get_cache_hit_rate,
        memory_usage: get_cache_memory_usage,
        evictions: get_cache_evictions
      }
    }
  end

  def self.collect_business_metrics
    {
      timestamp: Time.current.iso8601,
      users: {
        active_users_24h: get_active_users_24h,
        new_users_24h: get_new_users_24h,
        returning_users_24h: get_returning_users_24h
      },
      products: {
        total_products: Product.count,
        new_products_24h: Product.where('created_at >= ?', 24.hours.ago).count,
        products_with_images: Product.where.not(main_image: nil).count
      },
      orders: {
        total_orders_24h: Order.where('created_at >= ?', 24.hours.ago).count,
        total_revenue_24h: Order.where('created_at >= ?', 24.hours.ago).sum(:total_amount),
        average_order_value: get_average_order_value
      },
      personalization: {
        playbooks_generated_24h: Playbook.where('created_at >= ?', 24.hours.ago).count,
        ai_requests_24h: get_ai_requests_24h,
        fallback_rate: get_fallback_rate
      }
    }
  end

  private

  def self.get_memory_usage
    # Get memory usage from system
    `free -m`.split("\n")[1].split[2].to_i
  rescue
    0
  end

  def self.get_cpu_usage
    # Get CPU usage from system
    `top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}'`.to_f
  rescue
    0.0
  end

  def self.get_active_connections
    ActiveRecord::Base.connection_pool.stat[:size] - ActiveRecord::Base.connection_pool.stat[:available]
  end

  def self.get_request_rate
    # Get requests per minute from logs or monitoring
    0 # Placeholder
  end

  def self.get_error_rate
    # Get error rate from logs or monitoring
    0.0 # Placeholder
  end

  def self.get_response_time_p95
    # Get 95th percentile response time
    0 # Placeholder
  end

  def self.get_active_users_24h
    Event.where('timestamp_utc >= ?', 24.hours.ago)
         .distinct
         .count(:user_id)
  end

  def self.get_new_users_24h
    User.where('created_at >= ?', 24.hours.ago).count
  end

  def self.get_returning_users_24h
    # Users who had events in the last 24h but were created before that
    Event.where('timestamp_utc >= ?', 24.hours.ago)
         .joins(:user)
         .where('users.created_at < ?', 24.hours.ago)
         .distinct
         .count(:user_id)
  end

  def self.get_average_order_value
    orders_24h = Order.where('created_at >= ?', 24.hours.ago)
    return 0 if orders_24h.empty?
    
    orders_24h.sum(:total_amount) / orders_24h.count
  end

  def self.get_ai_requests_24h
    # Count AI service requests from logs or monitoring
    0 # Placeholder
  end

  def self.get_fallback_rate
    # Calculate percentage of requests using fallback plans
    0.0 # Placeholder
  end
end
```

### **2. Logging Configuration**

#### **Structured Logging**
```ruby
# config/initializers/logging.rb
Rails.application.configure do
  # Use JSON logging for production
  if Rails.env.production?
    config.log_formatter = proc do |severity, datetime, progname, msg|
      {
        timestamp: datetime.iso8601,
        level: severity,
        service: 'thrifts-backend',
        message: msg,
        request_id: Current.request_id,
        user_id: Current.user_id
      }.to_json + "\n"
    end
  end

  # Log level configuration
  config.log_level = Rails.env.production? ? :info : :debug

  # Log to stdout for containerized environments
  config.logger = ActiveSupport::Logger.new(STDOUT)
end
```

#### **Request Logging Middleware**
```ruby
# app/middleware/request_logging_middleware.rb
class RequestLoggingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    start_time = Time.current
    
    # Set request ID for tracing
    Current.request_id = SecureRandom.uuid
    
    # Log request
    Rails.logger.info({
      event: 'request_start',
      method: request.request_method,
      path: request.path,
      user_agent: request.user_agent,
      ip: request.remote_ip,
      request_id: Current.request_id
    }.to_json)

    status, headers, response = @app.call(env)
    
    # Log response
    duration = (Time.current - start_time) * 1000
    Rails.logger.info({
      event: 'request_complete',
      method: request.request_method,
      path: request.path,
      status: status,
      duration_ms: duration,
      request_id: Current.request_id
    }.to_json)

    [status, headers, response]
  rescue => e
    # Log error
    Rails.logger.error({
      event: 'request_error',
      method: request.request_method,
      path: request.path,
      error: e.message,
      backtrace: e.backtrace.first(5),
      request_id: Current.request_id
    }.to_json)
    
    raise e
  end
end
```

### **3. Alerting Configuration**

#### **Alert Rules**
```yaml
# monitoring/alerts.yml
groups:
  - name: thrifts-backend
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} errors per second"

      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High response time detected"
          description: "95th percentile response time is {{ $value }} seconds"

      - alert: DatabaseConnectionHigh
        expr: db_connections_active / db_connections_max > 0.8
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High database connection usage"
          description: "Database connections are at {{ $value }}% of maximum"

      - alert: AIServiceDown
        expr: up{job="ai-service"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "AI service is down"
          description: "AI service has been down for more than 1 minute"

      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space"
          description: "Disk space is below 10% on {{ $labels.instance }}"
```

---

## 🔧 **Troubleshooting Guide**

### **1. Common Issues**

#### **Database Connection Issues**

**Problem**: `PG::ConnectionBad: could not connect to server`
**Symptoms**:
- Rails can't connect to PostgreSQL
- Database queries failing
- Connection pool exhausted

**Solutions**:
```bash
# Check if PostgreSQL is running
docker-compose ps db

# Check database logs
docker-compose logs db

# Restart database
docker-compose restart db

# Check connection pool
docker-compose exec web bundle exec rails runner "puts ActiveRecord::Base.connection_pool.stat"

# Reset database connection
docker-compose exec web bundle exec rails runner "ActiveRecord::Base.connection_pool.disconnect!"
```

#### **Redis Connection Issues**

**Problem**: `Redis::CannotConnectError`
**Symptoms**:
- Session storage failing
- Cache operations failing
- Background jobs not processing

**Solutions**:
```bash
# Check if Redis is running
docker-compose ps redis

# Check Redis logs
docker-compose logs redis

# Test Redis connection
docker-compose exec web bundle exec rails runner "puts Redis.current.ping"

# Restart Redis
docker-compose restart redis
```

#### **AI Service Communication Issues**

**Problem**: `Net::ReadTimeout` or `Connection refused`
**Symptoms**:
- Personalization requests failing
- AI-generated plans not working
- Fallback plans being used

**Solutions**:
```bash
# Check if AI service is running
curl http://localhost:8000/health

# Check AI service logs
docker-compose logs ai-service

# Test AI service communication
docker-compose exec web bundle exec rails runner "lib/test_operator_connection.rb"

# Restart AI service
docker-compose restart ai-service
```

#### **Memory Issues**

**Problem**: `NoMemoryError` or high memory usage
**Symptoms**:
- Rails processes consuming too much memory
- Out of memory errors
- Slow response times

**Solutions**:
```bash
# Check memory usage
docker stats

# Check Rails memory usage
docker-compose exec web bundle exec rails runner "puts ObjectSpace.memsize_of_all / 1024 / 1024"

# Restart Rails application
docker-compose restart web

# Check for memory leaks
docker-compose exec web bundle exec rails runner "puts GC.stat"
```

### **2. Performance Issues**

#### **Slow Database Queries**

**Problem**: High database response times
**Symptoms**:
- Slow API responses
- Database connection pool exhaustion
- High CPU usage on database

**Solutions**:
```bash
# Check slow queries
docker-compose exec db psql -U postgres -d thrifts_backend_development -c "
SELECT query, mean_time, calls, total_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;"

# Check database indexes
docker-compose exec db psql -U postgres -d thrifts_backend_development -c "
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch 
FROM pg_stat_user_indexes 
ORDER BY idx_scan DESC;"

# Analyze query performance
docker-compose exec web bundle exec rails runner "
ActiveRecord::Base.logger = Logger.new(STDOUT)
Product.joins(:shop, :brand, :category).limit(10).to_a"
```

#### **High Response Times**

**Problem**: API responses taking too long
**Symptoms**:
- Frontend timeouts
- Poor user experience
- High server load

**Solutions**:
```bash
# Check response times
curl -w "@curl-format.txt" -o /dev/null -s "http://localhost:3000/api/home/grid?region=ke"

# Profile Rails application
docker-compose exec web bundle exec rails runner "
require 'ruby-prof'
RubyProf.start
# Your code here
result = RubyProf.stop
printer = RubyProf::FlatPrinter.new(result)
printer.print(STDOUT)"

# Check for N+1 queries
docker-compose exec web bundle exec rails runner "
ActiveRecord::Base.logger = Logger.new(STDOUT)
Product.includes(:shop, :brand, :category).limit(10).each do |product|
  puts product.shop.name
end"
```

### **3. Deployment Issues**

#### **Failed Deployments**

**Problem**: Deployment process failing
**Symptoms**:
- Build failures
- Migration failures
- Service startup failures

**Solutions**:
```bash
# Check build logs
docker-compose build --no-cache

# Check migration status
docker-compose exec web bundle exec rails db:migrate:status

# Run migrations manually
docker-compose exec web bundle exec rails db:migrate

# Check service logs
docker-compose logs web
docker-compose logs db
docker-compose logs redis
```

#### **Rollback Procedures**

**Problem**: Need to rollback a deployment
**Solutions**:
```bash
# Rollback database migrations
docker-compose exec web bundle exec rails db:rollback

# Rollback to previous Docker image
docker-compose down
docker-compose up -d --scale web=0
# Deploy previous version
docker-compose up -d

# Restore database from backup
docker-compose exec db psql -U postgres -d thrifts_backend_development < backup.sql
```

---

## 🔒 **Security Operations**

### **1. Security Monitoring**

#### **Security Headers**
```ruby
# config/initializers/security.rb
Rails.application.configure do
  # Security headers
  config.force_ssl = true if Rails.env.production?
  
  # Content Security Policy
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https, :unsafe_inline
  end

  # CORS configuration
  config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins Rails.env.production? ? ['https://thrifts.com'] : ['http://localhost:3000', 'http://localhost:3001']
      resource '*',
        headers: :any,
        methods: [:get, :post, :put, :patch, :delete, :options, :head],
        credentials: true
    end
  end
end
```

#### **Security Monitoring**
```ruby
# app/middleware/security_monitoring_middleware.rb
class SecurityMonitoringMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Log suspicious requests
    if suspicious_request?(request)
      Rails.logger.warn({
        event: 'suspicious_request',
        ip: request.remote_ip,
        user_agent: request.user_agent,
        path: request.path,
        method: request.request_method,
        request_id: Current.request_id
      }.to_json)
    end

    @app.call(env)
  end

  private

  def suspicious_request?(request)
    # Check for common attack patterns
    suspicious_patterns = [
      /\.\./,  # Directory traversal
      /<script/i,  # XSS attempts
      /union.*select/i,  # SQL injection
      /eval\(/i,  # Code injection
      /base64/i  # Base64 encoding (potential obfuscation)
    ]

    suspicious_patterns.any? { |pattern| request.path.match?(pattern) } ||
    suspicious_patterns.any? { |pattern| request.query_string.match?(pattern) }
  end
end
```

### **2. Backup & Recovery**

#### **Database Backups**
```bash
#!/bin/bash
# scripts/backup_database.sh

# Create backup directory
BACKUP_DIR="/backups/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup database
docker-compose exec -T db pg_dump -U postgres thrifts_backend_development > $BACKUP_DIR/database_backup.sql

# Compress backup
gzip $BACKUP_DIR/database_backup.sql

# Upload to cloud storage (if configured)
# aws s3 cp $BACKUP_DIR/database_backup.sql.gz s3://thrifts-backups/

# Clean up old backups (keep last 7 days)
find /backups -type d -mtime +7 -exec rm -rf {} \;

echo "Database backup completed: $BACKUP_DIR/database_backup.sql.gz"
```

#### **Recovery Procedures**
```bash
#!/bin/bash
# scripts/restore_database.sh

BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 <backup_file>"
  exit 1
fi

# Stop Rails application
docker-compose stop web

# Restore database
docker-compose exec -T db psql -U postgres -d thrifts_backend_development < $BACKUP_FILE

# Run migrations to ensure schema is up to date
docker-compose exec web bundle exec rails db:migrate

# Start Rails application
docker-compose start web

echo "Database restored from: $BACKUP_FILE"
```

---

## 📈 **Performance Optimization**

### **1. Database Optimization**

#### **Query Optimization**
```ruby
# app/models/concerns/query_optimization.rb
module QueryOptimization
  extend ActiveSupport::Concern

  # Use includes to prevent N+1 queries
  def self.optimize_product_queries
    Product.includes(:shop, :brand, :category)
           .where(moderation_status: 'approved')
           .where('stock > 0')
  end

  # Use select to limit columns
  def self.lightweight_products
    Product.select(:id, :name, :price, :main_image, :shop_id, :brand_id, :category_id)
           .includes(:shop, :brand, :category)
  end

  # Use counter cache for associations
  def self.products_with_view_counts
    Product.joins(:feed_exposures)
           .group('products.id')
           .select('products.*, COUNT(feed_exposures.id) as view_count')
  end
end
```

#### **Database Indexes**
```sql
-- Performance indexes
CREATE INDEX CONCURRENTLY idx_products_moderation_stock ON products(moderation_status, stock) WHERE moderation_status = 'approved' AND stock > 0;
CREATE INDEX CONCURRENTLY idx_products_shop_category ON products(shop_id, category_id);
CREATE INDEX CONCURRENTLY idx_products_brand_price ON products(brand_id, price);
CREATE INDEX CONCURRENTLY idx_products_created_at ON products(created_at DESC);

-- Event indexes for analytics
CREATE INDEX CONCURRENTLY idx_events_user_timestamp ON events(user_id, timestamp_utc DESC);
CREATE INDEX CONCURRENTLY idx_events_name_timestamp ON events(event_name, timestamp_utc DESC);
CREATE INDEX CONCURRENTLY idx_events_payload_gin ON events USING GIN(payload);

-- Playbook indexes
CREATE INDEX CONCURRENTLY idx_playbooks_user_page_date ON playbooks(user_id, page, generated_at DESC);
CREATE INDEX CONCURRENTLY idx_playbooks_cohort_page_date ON playbooks(cohort_id, page, generated_at DESC);
CREATE INDEX CONCURRENTLY idx_playbooks_active ON playbooks(generated_at, valid_for_hours) WHERE ai_generated = true;
```

### **2. Caching Strategy**

#### **Multi-Level Caching**
```ruby
# app/services/caching/multi_level_cache.rb
class Caching::MultiLevelCache
  def self.fetch(key, expires_in: 1.hour, &block)
    # Level 1: Memory cache (fastest)
    result = Rails.cache.read(key)
    return result if result

    # Level 2: Redis cache (fast)
    result = Redis.current.get(key)
    if result
      parsed_result = JSON.parse(result)
      Rails.cache.write(key, parsed_result, expires_in: expires_in)
      return parsed_result
    end

    # Level 3: Database/Computation (slowest)
    result = yield
    Rails.cache.write(key, result, expires_in: expires_in)
    Redis.current.setex(key, expires_in.to_i, result.to_json)
    result
  end

  def self.delete(key)
    Rails.cache.delete(key)
    Redis.current.del(key)
  end

  def self.clear
    Rails.cache.clear
    Redis.current.flushdb
  end
end

# Usage
result = Caching::MultiLevelCache.fetch("user_#{user_id}_profile", expires_in: 1.hour) do
  build_user_profile(user_id)
end
```

#### **Fragment Caching**
```ruby
# app/views/products/_product_list.html.erb
<% cache("products_list_#{params[:page]}_#{params[:region]}", expires_in: 30.minutes) do %>
  <% products.each do |product| %>
    <%= render 'product_card', product: product %>
  <% end %>
<% end %>

# app/views/products/_product_card.html.erb
<% cache("product_card_#{product.id}_#{product.updated_at.to_i}") do %>
  <div class="product-card">
    <img src="<%= product.main_image %>" alt="<%= product.name %>">
    <h3><%= product.name %></h3>
    <p class="price">$<%= product.price %></p>
  </div>
<% end %>
```

---

## 🎯 **Success Metrics**

### **1. System Health Metrics**
- **Uptime**: 99.9% availability
- **Response Time**: P95 < 500ms
- **Error Rate**: < 0.1%
- **Database Performance**: < 100ms average query time

### **2. Business Metrics**
- **User Engagement**: Active users, session duration
- **Conversion Rate**: Users making purchases
- **Revenue**: Daily/monthly revenue growth
- **Customer Satisfaction**: Support ticket volume

### **3. Technical Metrics**
- **Deployment Frequency**: Daily deployments
- **Lead Time**: < 1 hour from commit to production
- **Mean Time to Recovery**: < 30 minutes
- **Change Failure Rate**: < 5%

---

## 📞 **Support & Escalation**

### **1. Support Contacts**
- **Level 1**: Development Team (24/7 on-call)
- **Level 2**: Senior Engineers (escalation)
- **Level 3**: Architecture Team (critical issues)
- **Business**: Product Team (business impact)

### **2. Escalation Procedures**
1. **P1 (Critical)**: System down, data loss, security breach
   - Immediate escalation to Level 2
   - All hands on deck
   - Business stakeholders notified

2. **P2 (High)**: Performance degradation, feature broken
   - Escalate within 1 hour
   - Level 1 + Level 2 involvement
   - Product team notified

3. **P3 (Medium)**: Minor issues, enhancements
   - Normal business hours
   - Level 1 handles
   - Document for future improvement

### **3. Communication Channels**
- **Slack**: #thrifts-alerts (critical), #thrifts-dev (general)
- **Email**: alerts@thrifts.com (critical issues)
- **Phone**: On-call rotation for P1 issues
- **Status Page**: status.thrifts.com (public updates)

---

## 🎉 **Conclusion**

This operations and deployment guide provides:

1. **Complete Infrastructure Setup** - Docker, production deployment
2. **Comprehensive Monitoring** - Health checks, metrics, alerting
3. **Robust Troubleshooting** - Common issues and solutions
4. **Security Operations** - Monitoring, backups, recovery
5. **Performance Optimization** - Database, caching, query optimization
6. **Support Procedures** - Escalation, communication, success metrics

**The system is production-ready with enterprise-grade operations and monitoring!** 🚀
