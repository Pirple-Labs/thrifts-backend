# 🏗️ System Architecture - Thrifts Backend

## 🎯 **Architecture Overview**

Thrifts backend is built as a modern, scalable e-commerce platform using Ruby on Rails with microservices-ready architecture, AI-powered personalization, and real-time analytics.

---

## 🏛️ **High-Level Architecture**

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend Layer                          │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   Web App       │   Mobile App    │   Admin Dashboard           │
│   (React/Next)  │   (iOS/Android) │   (React)                   │
└─────────────────┴─────────────────┴─────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                        API Gateway                             │
├─────────────────────────────────────────────────────────────────┤
│  Load Balancer │ Rate Limiting │ Authentication │ CORS          │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Rails Application                         │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   Controllers   │   Services      │   Background Jobs           │
│   (API Layer)   │   (Business)    │   (Async Processing)        │
└─────────────────┴─────────────────┴─────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Data Layer                                │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   PostgreSQL    │   Redis Cache   │   AI Services               │
│   (Primary DB)  │   (Sessions)    │   (Personalization)         │
└─────────────────┴─────────────────┴─────────────────────────────┘
```

---

## 🧩 **Core Components**

### **1. API Layer (Controllers)**
- **RESTful endpoints** for all client interactions
- **Authentication & Authorization** with JWT tokens
- **Request validation** and parameter sanitization
- **Response formatting** and error handling

### **2. Business Logic Layer (Services)**
- **Personalization Engine**: AI-powered content recommendations
- **Analytics Engine**: Real-time event tracking and processing
- **Search Engine**: Product discovery and filtering
- **Order Management**: E-commerce workflow handling

### **3. Data Access Layer (Models)**
- **ActiveRecord models** for database interactions
- **Data validation** and business rules
- **Associations** and relationships
- **Query optimization** and caching

### **4. External Services**
- **AI/ML Services**: Personalization and recommendations
- **Payment Gateways**: M-Pesa and other payment methods
- **Cloud Storage**: Image and asset management
- **Email Services**: Notifications and communications

---

## 🗄️ **Database Architecture**

### **PostgreSQL Schema**

#### **Core Tables**
```sql
-- Users and Authentication
users (id, email, name, created_at, updated_at)
shops (id, name, description, user_id, store_logo_url)

-- Products and Catalog
products (id, name, price, description, shop_id, category_id, brand_id)
categories (id, name, description, parent_id)
brands (id, name, description)

-- Orders and Commerce
orders (id, user_id, shop_id, total_amount, status, created_at)
order_items (id, order_id, product_id, quantity, price)
cart_items (id, user_id, product_id, quantity)

-- Analytics and Events
events (id, event_id, user_id, event_name, timestamp_utc, payload)
feeds (id, user_id, page, content, generated_at)
playbooks (id, user_id, page, content, valid_for_hours)
```

#### **Vector Search (pgvector)**
```sql
-- Product embeddings for similarity search
product_embeddings (id, product_id, embedding_vector)
```

### **Redis Cache Structure**
```
# Session Management
sessions:user_id -> session_data

# API Response Caching
cache:api:home_grid:user_id -> response_data
cache:api:similar_products:shop_id:product_id -> response_data

# Real-time Analytics
analytics:events:user_id -> event_queue
analytics:metrics:daily -> aggregated_data
```

---

## 🔄 **Data Flow Architecture**

### **1. User Request Flow**
```
User Request → Load Balancer → Rails App → Service Layer → Database
                ↓
Response ← JSON Formatter ← Business Logic ← Data Processing ← Query Results
```

### **2. Personalization Flow**
```
User Action → Event Tracking → Analytics Engine → AI Service → Playbook Generation
                ↓
Personalized Content ← Content Assembly ← Recommendation Engine ← User Profile
```

### **3. Real-time Analytics Flow**
```
User Events → Event Ingestion → Real-time Processing → Analytics Storage
                ↓
Dashboard Updates ← Aggregation Engine ← Metrics Calculation ← Data Processing
```

---

## 🚀 **Service Architecture**

### **Personalization Services**

#### **PlaybookExecutor**
- **Purpose**: Executes AI-generated playbooks for personalized content
- **Input**: User context, page type, region
- **Output**: Personalized content sections
- **Caching**: 5-minute TTL for playbook results

#### **SnapshotBuilder**
- **Purpose**: Builds comprehensive user profiles for AI context
- **Input**: User events, preferences, behavior patterns
- **Output**: User snapshot with behavioral insights
- **Caching**: 1-hour TTL for user snapshots

#### **Retrieval Services**
- **SearchFusion**: Advanced product search with multiple algorithms
- **Lookalikes**: Similar product recommendations
- **Complements**: Cross-selling product suggestions
- **Trending**: Popular product identification

### **Analytics Services**

#### **EventIngestion**
- **Purpose**: Processes and stores user events in real-time
- **Input**: Event streams from frontend
- **Output**: Structured event data in database
- **Performance**: Bulk processing for high throughput

#### **CostMeter**
- **Purpose**: Tracks API usage and costs for billing
- **Input**: API call metrics and resource usage
- **Output**: Usage reports and billing data
- **Monitoring**: Real-time cost tracking

### **Search Services**

#### **ProductSearch**
- **Purpose**: Advanced product discovery with filters
- **Input**: Search queries, filters, pagination
- **Output**: Ranked product results
- **Features**: Full-text search, vector similarity, faceted search

#### **SimilarProducts**
- **Purpose**: Product recommendations based on similarity
- **Input**: Product ID, shop ID, similarity criteria
- **Output**: Ranked similar products
- **Algorithms**: Content-based, collaborative filtering

---

## 🔧 **Technical Architecture**

### **Rails Application Structure**
```
app/
├── controllers/
│   ├── api/
│   │   ├── feed_controller.rb          # Home page and feeds
│   │   ├── merchants/
│   │   │   └── shops_controller.rb     # Shop management
│   │   ├── products_controller.rb      # Product APIs
│   │   └── events_controller.rb        # Analytics
│   └── application_controller.rb
├── models/
│   ├── user.rb
│   ├── product.rb
│   ├── shop.rb
│   ├── event.rb
│   └── playbook.rb
├── services/
│   ├── personalization/
│   │   ├── playbook_executor.rb
│   │   ├── playbook_generator.rb
│   │   └── snapshot_builder.rb
│   ├── analytics/
│   │   └── event_processor.rb
│   └── search/
│       └── product_search.rb
└── jobs/
    ├── analytics_processor.rb
    └── playbook_generator_job.rb
```

### **Configuration Management**
```
config/
├── database.yml           # Database connections
├── routes.rb              # API routing
├── initializers/
│   ├── cors.rb           # CORS configuration
│   └── redis.rb          # Redis configuration
└── environments/
    ├── development.rb     # Development settings
    └── production.rb      # Production settings
```

---

## 🐳 **Infrastructure Architecture**

### **Docker Containerization**
```yaml
# docker-compose.yml
services:
  web:                    # Rails application
    build: .
    ports: ["3000:3000"]
    depends_on: [db, redis]
    
  db:                     # PostgreSQL database
    image: pgvector/pgvector:pg15
    ports: ["5432:5432"]
    volumes: [postgres_data:/var/lib/postgresql/data]
    
  redis:                  # Redis cache
    image: redis:7-alpine
    ports: ["6379:6379"]
    volumes: [redis_data:/data]
```

### **Network Architecture**
```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Network                               │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   Web Container │   DB Container  │   Redis Container           │
│   (Rails App)   │   (PostgreSQL)  │   (Cache/Sessions)          │
│   Port: 3000    │   Port: 5432    │   Port: 6379                │
└─────────────────┴─────────────────┴─────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Host Machine                                 │
├─────────────────────────────────────────────────────────────────┤
│  Port Mapping: 3000:3000, 5432:5432, 6379:6379                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 **Performance Architecture**

### **Caching Strategy**
```
┌─────────────────────────────────────────────────────────────────┐
│                      Caching Layers                            │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   Application   │   Database      │   CDN/Static                │
│   (Redis)       │   (Query Cache) │   (Images/Assets)           │
│   TTL: 5-60min  │   TTL: 1-24hrs  │   TTL: 24hrs-1week          │
└─────────────────┴─────────────────┴─────────────────────────────┘
```

### **Database Optimization**
- **Indexes**: Optimized for common query patterns
- **Connection Pooling**: Efficient database connections
- **Query Optimization**: N+1 query prevention
- **Read Replicas**: Prepared for scaling

### **API Performance**
- **Response Caching**: Frequently accessed data
- **Pagination**: Efficient large dataset handling
- **Compression**: Gzip response compression
- **Rate Limiting**: API abuse prevention

---

## 🔒 **Security Architecture**

### **Authentication & Authorization**
```
┌─────────────────────────────────────────────────────────────────┐
│                    Security Layers                              │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   JWT Tokens    │   Role-Based    │   API Rate Limiting         │
│   (Stateless)   │   Access Control│   (DoS Protection)          │
└─────────────────┴─────────────────┴─────────────────────────────┘
```

### **Data Protection**
- **Input Validation**: SQL injection prevention
- **Output Encoding**: XSS protection
- **HTTPS**: Encrypted communication
- **Data Encryption**: Sensitive data protection

---

## 📈 **Scalability Architecture**

### **Horizontal Scaling**
```
┌─────────────────────────────────────────────────────────────────┐
│                    Load Balancer                                │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   Rails App 1   │   Rails App 2   │   Rails App N               │
│   (Instance 1)  │   (Instance 2)  │   (Instance N)              │
└─────────────────┴─────────────────┴─────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Shared Services                              │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   PostgreSQL    │   Redis Cluster │   AI Services               │
│   (Master/Slave)│   (Distributed) │   (Microservices)           │
└─────────────────┴─────────────────┴─────────────────────────────┘
```

### **Microservices Readiness**
- **Service Boundaries**: Clear separation of concerns
- **API Contracts**: Well-defined interfaces
- **Event-Driven**: Asynchronous communication
- **Independent Deployment**: Service-specific releases

---

## 🔍 **Monitoring Architecture**

### **Health Monitoring**
```
┌─────────────────────────────────────────────────────────────────┐
│                    Monitoring Stack                             │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   Application   │   Infrastructure│   Business Metrics          │
│   (APM)         │   (System)      │   (Analytics)               │
└─────────────────┴─────────────────┴─────────────────────────────┘
```

### **Observability**
- **Logging**: Structured application logs
- **Metrics**: Performance and business metrics
- **Tracing**: Request flow tracking
- **Alerting**: Proactive issue detection

---

## 🚀 **Deployment Architecture**

### **Environment Strategy**
```
┌─────────────────────────────────────────────────────────────────┐
│                    Deployment Pipeline                          │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   Development   │   Staging       │   Production                │
│   (Local Docker)│   (Cloud)       │   (Cloud + CDN)             │
└─────────────────┴─────────────────┴─────────────────────────────┘
```

### **CI/CD Pipeline**
1. **Code Commit** → Git repository
2. **Automated Tests** → Unit, integration, e2e
3. **Build** → Docker image creation
4. **Deploy** → Staging environment
5. **Validation** → Health checks and smoke tests
6. **Release** → Production deployment

---

*This architecture provides a solid foundation for a scalable, maintainable, and high-performance e-commerce platform with advanced personalization capabilities.*
