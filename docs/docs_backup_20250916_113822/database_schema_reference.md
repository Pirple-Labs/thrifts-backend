# Database Schema Reference

## Overview

This document details the database schema for the personalization system, including table structures, relationships, and data flow patterns.

## Core Tables

### feeds
**Purpose**: Track personalized feed instances with metadata and caching keys.

```sql
CREATE TABLE feeds (
  id SERIAL PRIMARY KEY,
  feed_uid VARCHAR NOT NULL UNIQUE,           -- Public UUID for API responses
  plan_id VARCHAR,                            -- Plan identifier (e.g., "operator_v1", "control_v1")
  user_id BIGINT REFERENCES users(id),        -- NULL for anonymous users
  session_id VARCHAR NOT NULL,                -- Client session identifier
  page VARCHAR NOT NULL,                      -- Context page (home, pdp, profile, etc.)
  intent_label VARCHAR,                       -- Detected user intent (search, browse, etc.)
  intent_confidence FLOAT,                    -- Confidence score for intent
  constraints JSONB NOT NULL DEFAULT '{}',   -- Search/filter constraints
  ttl_seconds INTEGER,                        -- Cache TTL for this feed
  is_cache_hit BOOLEAN,                       -- Whether this was served from cache
  prompt_version VARCHAR,                     -- Operator prompt version
  model_version VARCHAR,                      -- AI model version used  
  index_version VARCHAR,                      -- Vector index version
  fingerprint VARCHAR,                        -- Content fingerprint for caching
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_feeds_feed_uid ON feeds(feed_uid);
CREATE INDEX idx_feeds_user_id ON feeds(user_id);
CREATE INDEX idx_feeds_plan_id ON feeds(plan_id);
```

**Sample Record**:
```json
{
  "id": 1001,
  "feed_uid": "550e8400-e29b-41d4-a716-446655440000",
  "plan_id": "operator_search_v1", 
  "user_id": 456,
  "session_id": "sess_abc123",
  "page": "home",
  "intent_label": "product_search",
  "intent_confidence": 0.87,
  "constraints": {
    "pickup_only": true,
    "region": "Nairobi",
    "geohash6": "s17h0m"
  },
  "ttl_seconds": 300,
  "is_cache_hit": false,
  "prompt_version": "qp_operator_v2",
  "model_version": "gpt-4-turbo",
  "index_version": "vec_2025_01_15",
  "fingerprint": "abc123def456...",
  "created_at": "2025-01-15T10:30:00Z",
  "updated_at": "2025-01-15T10:30:00Z"
}
```

### feed_items
**Purpose**: Server-truth exposure records - what products were shown, in what order, with what context.

```sql
CREATE TABLE feed_items (
  id SERIAL PRIMARY KEY,
  feed_id BIGINT NOT NULL REFERENCES feeds(id),
  product_id BIGINT NOT NULL REFERENCES products(id), 
  section VARCHAR,                            -- Section identifier (grid, trending, search_results)
  position INTEGER,                           -- 0-based position within section
  reason TEXT,                               -- Human-readable explanation
  matched_phrase TEXT,                       -- Search term or query that matched
  vec_score FLOAT,                           -- Vector similarity score
  weight FLOAT,                              -- Query weight applied
  role VARCHAR,                              -- Query role (search, trending, similar, etc.)
  final_score FLOAT,                         -- Final ranking score after business rules
  distance_km FLOAT,                         -- Geographic distance (if applicable)
  local_pop_z FLOAT,                         -- Local popularity z-score
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_feed_items_feed_id ON feed_items(feed_id);
CREATE INDEX idx_feed_items_product_id ON feed_items(product_id);
CREATE INDEX idx_feed_items_position ON feed_items(feed_id, position);
```

**Sample Record**:
```json
{
  "id": 5001,
  "feed_id": 1001,
  "product_id": 789,
  "section": "grid", 
  "position": 2,
  "reason": "Close to the styles you viewed",
  "matched_phrase": "blue summer dress",
  "vec_score": 0.87,
  "weight": 1.2,
  "role": "search",
  "final_score": 1.044,
  "distance_km": 15.3,
  "local_pop_z": 0.45,
  "created_at": "2025-01-15T10:30:01Z",
  "updated_at": "2025-01-15T10:30:01Z"
}
```

### events
**Purpose**: User interaction events for analytics and attribution.

```sql
CREATE TABLE events (
  id SERIAL PRIMARY KEY,
  event_id VARCHAR NOT NULL UNIQUE,           -- Client-provided unique ID (idempotency)
  user_id BIGINT REFERENCES users(id),        -- NULL for anonymous users
  anonymous_id VARCHAR,                       -- Anonymous user identifier
  session_id VARCHAR NOT NULL,               -- Session identifier
  event_name VARCHAR NOT NULL,               -- Event type (product_click, add_to_cart, etc.)
  timestamp_utc TIMESTAMP NOT NULL,          -- Event timestamp (client-reported, clamped)
  received_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  page VARCHAR NOT NULL,                     -- Page context
  region VARCHAR NOT NULL,                   -- Geographic region
  geohash6 VARCHAR,                          -- Geohash for location
  schema_version VARCHAR NOT NULL DEFAULT 'v1',
  payload JSONB NOT NULL DEFAULT '{}'       -- Event-specific data (whitelisted keys only)
);

CREATE UNIQUE INDEX idx_events_event_id ON events(event_id);
CREATE INDEX idx_events_user_session_time ON events(user_id, session_id, timestamp_utc);
CREATE INDEX idx_events_name_time ON events(event_name, timestamp_utc);
CREATE INDEX idx_events_payload_gin ON events USING gin(payload);
```

**Sample Records**:
```json
// Product impression
{
  "event_id": "evt_impression_123",
  "user_id": 456,
  "session_id": "sess_abc123",
  "event_name": "product_impression",
  "timestamp_utc": "2025-01-15T10:30:05Z",
  "page": "home",
  "region": "Nairobi",
  "payload": {
    "feed_id": "550e8400-e29b-41d4-a716-446655440000",
    "plan_id": "operator_search_v1",
    "section": "grid",
    "product_id": 789,
    "position": 2,
    "reason": "Close to the styles you viewed"
  }
}

// Product click  
{
  "event_id": "evt_click_124",
  "user_id": 456,
  "session_id": "sess_abc123", 
  "event_name": "product_click",
  "timestamp_utc": "2025-01-15T10:31:15Z",
  "page": "home",
  "region": "Nairobi",
  "payload": {
    "feed_id": "550e8400-e29b-41d4-a716-446655440000",
    "plan_id": "operator_search_v1",
    "product_id": 789,
    "position": 2
  }
}

// Add to cart
{
  "event_id": "evt_atc_125",
  "user_id": 456,
  "session_id": "sess_abc123",
  "event_name": "add_to_cart", 
  "timestamp_utc": "2025-01-15T10:32:30Z",
  "page": "pdp",
  "region": "Nairobi",
  "payload": {
    "product_id": 789,
    "quantity": 2,
    "price_cents": 2999,
    "source_feed_id": "550e8400-e29b-41d4-a716-446655440000",
    "source_plan_id": "operator_search_v1"
  }
}
```

## Attribution & Analytics Tables

### exposure_outcomes
**Purpose**: Hourly ETL results linking exposures to user actions within time windows.

```sql
CREATE TABLE exposure_outcomes (
  id SERIAL PRIMARY KEY,
  feed_uid VARCHAR NOT NULL,                  -- Links to feeds.feed_uid
  plan_id VARCHAR NOT NULL,                   -- Plan that generated exposure
  section VARCHAR NOT NULL,                   -- Section within feed
  product_id BIGINT NOT NULL,                -- Product that was exposed
  position INTEGER NOT NULL,                  -- Position within section (0-based)
  clicked_5m BOOLEAN NOT NULL DEFAULT FALSE, -- Click within 5 minutes
  atc_30m BOOLEAN NOT NULL DEFAULT FALSE,    -- Add-to-cart within 30 minutes  
  purchased_24h BOOLEAN NOT NULL DEFAULT FALSE, -- Purchase within 24 hours
  item_weight_w1 FLOAT NOT NULL DEFAULT 0.0, -- Computed attribution weight
  window_start TIMESTAMP NOT NULL,           -- Attribution window start
  window_end TIMESTAMP NOT NULL,             -- Attribution window end
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_exposure_tuple ON exposure_outcomes(feed_uid, plan_id, section, product_id, position);
CREATE INDEX idx_exposure_outcomes_plan_date ON exposure_outcomes(plan_id, DATE(window_start));
```

**Sample Record**:
```json
{
  "id": 2001,
  "feed_uid": "550e8400-e29b-41d4-a716-446655440000",
  "plan_id": "operator_search_v1",
  "section": "grid",
  "product_id": 789,
  "position": 2,
  "clicked_5m": true,
  "atc_30m": true, 
  "purchased_24h": false,
  "item_weight_w1": 3.47,  // (1×clicked + 5×atc) × position_discount
  "window_start": "2025-01-15T10:30:00Z",
  "window_end": "2025-01-16T10:30:00Z",
  "created_at": "2025-01-15T11:30:00Z",
  "updated_at": "2025-01-15T11:30:00Z"
}
```

**Attribution Formula**:
```
item_weight_w1 = (1×clicked_5m + 5×atc_30m + 20×purchased_24h) × (1/log2(2 + position))
```

### plan_metrics  
**Purpose**: Daily aggregated performance metrics per plan.

```sql
CREATE TABLE plan_metrics (
  id SERIAL PRIMARY KEY,
  plan_id VARCHAR NOT NULL,                   -- Plan identifier
  metric_date DATE NOT NULL,                  -- Date of metrics
  plan_score FLOAT NOT NULL DEFAULT 0.0,     -- Aggregate plan performance score
  p95_latency_ms FLOAT NOT NULL DEFAULT 0.0, -- 95th percentile response time
  cache_hit_rate FLOAT NOT NULL DEFAULT 0.0, -- Plan cache hit rate (0.0-1.0)
  empty_section_rate FLOAT NOT NULL DEFAULT 0.0, -- Rate of empty sections
  requests INTEGER NOT NULL DEFAULT 0,       -- Total requests served
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX idx_plan_metrics_plan_date ON plan_metrics(plan_id, metric_date);
```

**Sample Record**:
```json
{
  "id": 3001,
  "plan_id": "operator_search_v1", 
  "metric_date": "2025-01-15",
  "plan_score": 127.45,        // Sum of item_weight_w1 + bonuses - penalties
  "p95_latency_ms": 890.5,
  "cache_hit_rate": 0.73,      // 73% cache hit rate
  "empty_section_rate": 0.02,  // 2% empty sections
  "requests": 1547,
  "created_at": "2025-01-16T02:00:00Z",
  "updated_at": "2025-01-16T02:00:00Z"
}
```

### user_profiles
**Purpose**: Non-PII user preferences and behavior patterns for personalization.

```sql
CREATE TABLE user_profiles (
  id SERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  version VARCHAR NOT NULL DEFAULT 'up_v1',  -- Profile schema version
  data JSONB NOT NULL DEFAULT '{}',          -- Profile data structure
  computed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX idx_user_profiles_user_version ON user_profiles(user_id, version);
```

**Sample Profile Data**:
```json
{
  "user_id": 456,
  "version": "up_v1",
  "data": {
    "price_band": "mid",                    // low, mid, high, luxury
    "price_spread": 0.35,                   // Price variance preference
    "top_categories": [
      {"id": 10, "name": "Women's Fashion", "affinity": 0.85, "last_seen": "2025-01-15T10:00:00Z"},
      {"id": 15, "name": "Electronics", "affinity": 0.23, "last_seen": "2025-01-10T14:30:00Z"}
    ],
    "top_shops": [
      {"id": 100, "name": "Fashion Hub", "affinity": 0.67, "orders": 3},
      {"id": 200, "name": "Tech Store", "affinity": 0.31, "orders": 1}
    ],
    "style_clusters": ["bohemian", "minimalist"],
    "last_3_pdp_ids": [789, 234, 567],
    "inactivity_bucket": "active",          // active, declining, inactive
    "session_intensity": "high",            // low, medium, high
    "last_search_terms_hashed": ["hash1", "hash2"] // Hashed for privacy
  },
  "computed_at": "2025-01-15T02:00:00Z"
}
```

## Vector & Search Tables

### product_embeddings
**Purpose**: Vector embeddings for semantic product search.

```sql
-- Note: This table structure from existing schema
CREATE TABLE product_embeddings (
  id SERIAL PRIMARY KEY,
  product_id BIGINT NOT NULL REFERENCES products(id),
  embedding vector(1536),                    -- OpenAI ada-002 embedding
  index_version VARCHAR,                     -- Version of embedding model/index
  embedded_at TIMESTAMP,                     -- When embedding was computed
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX idx_product_embeddings_product_id ON product_embeddings(product_id);
CREATE INDEX idx_product_embeddings_embedding_ivfflat ON product_embeddings 
  USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
```

**Sample Record**:
```json
{
  "id": 4001,
  "product_id": 789,
  "embedding": [0.123, -0.456, 0.789, ...], // 1536 floats
  "index_version": "vec_2025_01_15",
  "embedded_at": "2025-01-15T03:15:00Z",
  "created_at": "2025-01-15T03:15:00Z", 
  "updated_at": "2025-01-15T03:15:00Z"
}
```

## Data Flow Patterns

### Feed Generation Flow

1. **Request** → `snapshot` (temporary)
2. **Snapshot** → `fingerprint` → `PlanCache` check
3. **Plan** → `VectorSearch` → candidates (temporary)
4. **Candidates** → `Ranker` → final items (temporary) 
5. **Final items** → `SlateWriter` → **feeds** + **feed_items** records
6. **Cache** → Redis (fingerprint → feed_uid + items + reasons)

### Event Attribution Flow

1. **Frontend** → **events** (real-time ingestion)
2. **Hourly ETL** → Join **feed_items** ↔ **events** → **exposure_outcomes**
3. **Daily ETL** → Aggregate **exposure_outcomes** → **plan_metrics**

### Personalization Learning Flow

1. **Events** → **User behavior analysis** (hourly)
2. **Behavior patterns** → **user_profiles.data** update
3. **Profile data** → **SnapshotBuilder** → Enhanced targeting

## Query Patterns

### Attribution Join Query
```sql
-- Find exposure outcomes for a specific feed
SELECT 
  fi.product_id,
  fi.position,
  fi.reason,
  eo.clicked_5m,
  eo.atc_30m,
  eo.purchased_24h,
  eo.item_weight_w1
FROM feed_items fi
LEFT JOIN exposure_outcomes eo ON (
  eo.feed_uid = (SELECT feed_uid FROM feeds WHERE id = fi.feed_id)
  AND eo.product_id = fi.product_id 
  AND eo.position = fi.position
)
WHERE fi.feed_id = 1001
ORDER BY fi.position;
```

### Plan Performance Query
```sql
-- Daily plan comparison
SELECT 
  plan_id,
  AVG(plan_score) as avg_score,
  AVG(p95_latency_ms) as avg_latency,
  AVG(cache_hit_rate) as avg_cache_hit,
  SUM(requests) as total_requests
FROM plan_metrics 
WHERE metric_date >= '2025-01-01'
GROUP BY plan_id
ORDER BY avg_score DESC;
```

### Vector Similarity Query
```sql
-- Find similar products using cosine similarity
SELECT 
  p.id,
  p.name,
  1 - (pe.embedding <=> $1::vector) AS similarity
FROM product_embeddings pe
JOIN products p ON p.id = pe.product_id
WHERE p.stock > 0 
  AND p.moderation_status = 'approved'
ORDER BY pe.embedding <-> $1::vector
LIMIT 50;
```

### Event Analytics Query  
```sql
-- Click-through rates by plan
SELECT 
  payload->>'plan_id' as plan_id,
  COUNT(*) FILTER (WHERE event_name = 'product_impression') as impressions,
  COUNT(*) FILTER (WHERE event_name = 'product_click') as clicks,
  ROUND(
    COUNT(*) FILTER (WHERE event_name = 'product_click')::float / 
    NULLIF(COUNT(*) FILTER (WHERE event_name = 'product_impression'), 0) * 100, 
    2
  ) as ctr_percent
FROM events
WHERE timestamp_utc >= NOW() - INTERVAL '7 days'
  AND payload ? 'plan_id'
GROUP BY payload->>'plan_id'
ORDER BY ctr_percent DESC;
```

## Data Retention & Cleanup

### Retention Policies
- **feeds**: 30 days (for debugging and cache validation)
- **feed_items**: 30 days (linked to feeds)
- **events**: 1 year (for long-term analytics)
- **exposure_outcomes**: 1 year (for attribution analysis)
- **plan_metrics**: 2 years (for trend analysis)
- **user_profiles**: Until user deletion (GDPR compliance)

### Cleanup Jobs
```sql
-- Clean up old feeds and related data
DELETE FROM feed_items 
WHERE feed_id IN (
  SELECT id FROM feeds 
  WHERE created_at < NOW() - INTERVAL '30 days'
);

DELETE FROM feeds 
WHERE created_at < NOW() - INTERVAL '30 days';

-- Archive old events (move to cold storage)
DELETE FROM events 
WHERE timestamp_utc < NOW() - INTERVAL '1 year';
```

## Performance Considerations

### Indexing Strategy
- **Time-based queries**: Compound indexes on (entity_id, timestamp)
- **Attribution joins**: Covering indexes on join tuples
- **Vector search**: IVFFlat indexes for embedding similarity
- **JSON queries**: GIN indexes on JSONB payload columns

### Partitioning Options
- **events**: Monthly partitions by timestamp_utc
- **exposure_outcomes**: Monthly partitions by window_start
- **plan_metrics**: Yearly partitions (low volume)

### Scaling Considerations
- **Read replicas**: For analytics queries on events/outcomes
- **Vector index tuning**: lists parameter based on data size
- **Cache warming**: Precompute common embeddings and plan results
- **ETL optimization**: Incremental processing with checkpoints

This schema supports the full attribution pipeline while maintaining query performance and data integrity for the personalization system.
