# Personalization API Reference

## Overview

This document provides detailed input/output specifications for the personalization system components, including API endpoints, services, and data flows.

## API Endpoints

### POST /api/feeds/start

**Purpose**: Initialize a personalized feed for a user session.

**Input Contract**:
```json
{
  "page": "home|pdp|profile|cart|checkout",
  "session_id": "string (required)",
  "user_id": "integer (optional)",
  "anonymous_id": "string (optional)",
  "region": "string (required)",
  "geohash6": "string (optional)",
  "pickup_only": "boolean (optional, default: false)",
  "limit": "integer (optional, default: 24, max: 60)",
  "pid": "integer (optional, product ID for PDP context)",
  
  // Search parameters (optional)
  "searchType": "text|image",
  "searchTerm": "string (2-256 chars, required if searchType=text)",
  "imageUrl": "string (Cloudinary URL, required if searchType=image)",
  "imageMetadata": {
    "image_name": "string (optional)",
    "image_size": "integer (optional)",
    "image_type": "string (optional)"
  }
}
```

**Input Validation**:
- `page` must be in ALLOWED_PAGES
- `session_id` is required
- `region` is required
- `limit` clamped to 1-60
- `searchTerm` length 2-256 if provided
- `imageUrl` must pass allowlist check if provided

**Output Contract**:
```json
{
  "feed_id": "uuid",
  "plan_id": "string",
  "ttl_seconds": 300,
  "sections": [
    {
      "id": "grid",
      "reason": null,
      "products": [
        {
          "id": 123,
          "name": "Product Name",
          "price": "29.99",
          "image": "https://...",
          "main_image": "https://...",
          "supplementary_images": ["https://..."],
          "shop": {
            "id": 456,
            "name": "Shop Name",
            "store_logo_url": "https://..."
          }
        }
      ]
    }
  ],
  "cursor": "base64_encoded_offset (nullable)",
  "hasMore": true,
  "trace": {
    "prompt_version": "qp_home_v1",
    "model_version": "ai_unknown",
    "index_version": "vec_2025_01_15"
  },
  "is_cache_hit": false,
  "intent": "search|browse|explore (nullable)"
}
```

**Error Responses**:
- 422: Invalid searchType, imageUrl host not allowed
- 400: Missing required fields
- 500: Internal server error (with fallback feed)

### POST /api/feeds/next

**Purpose**: Get next page of feed items using cursor-based pagination.

**Input Contract**:
```json
{
  "feed_id": "uuid (required)",
  "cursor": "string (optional, from previous response)",
  "limit": "integer (optional, default: 24, max: 60)"
}
```

**Output Contract**: Same as `/start` but with updated cursor and products for the next slice.

**Error Responses**:
- 404: Feed not found
- 400: Invalid cursor

### POST /api/events

**Purpose**: Ingest user interaction events for analytics and personalization.

**Input Contract**:
```json
{
  "events": [
    {
      "event_id": "unique_string (required)",
      "user_id": "integer (optional)",
      "anonymous_id": "string (optional)",
      "session_id": "string (required)",
      "event_name": "string (required)",
      "timestamp_utc": "ISO8601 string (optional, defaults to now)",
      "page": "string (required, must be in allowed pages)",
      "region": "string (required)",
      "geohash6": "string (optional)",
      "schema_version": "string (optional, default: v1)",
      "payload": {
        // Whitelisted keys only (see PAYLOAD_WHITELIST)
        "feed_id": "uuid",
        "plan_id": "string",
        "section": "string",
        "position": "integer",
        "product_id": "integer",
        "search_term": "string",
        "search_type": "text|image",
        "quantity": "integer",
        "price_cents": "integer",
        "category_id": "integer",
        "shop_id": "integer",
        "reason": "string",
        "source_plan_id": "string",
        "source_section": "string",
        "source_feed_id": "uuid",
        "source_page": "string"
      }
    }
  ],
  "client_sent_at": "ISO8601 string (optional)",
  "app_version": "string (optional)",
  "sdk_version": "string (optional)"
}
```

**Payload Whitelist**: Only these keys are accepted in event payloads:
```
feed_id, plan_id, section, position, product_id, items, products, 
slice_index, cursor, search_term, search_type, image_name, image_size, 
image_type, quantity, price_cents, category_id, shop_id, reason,
source_plan_id, source_section, source_feed_id, source_page
```

**Blacklisted Keys**: `imageUrl` is explicitly rejected to prevent PII leaks.

**Output Contract**:
```json
{
  "accepted": 15,
  "rejected": 2,
  "received_at": "2025-01-15T10:30:00Z"
}
```

**Validation Rules**:
- `event_id` must be unique (idempotent)
- Feed events require valid `feed_id` (not "fallback")
- Timestamps clamped to reasonable range (±10min future, max 7 days old)
- Event-specific required fields enforced per EVENT_RULES

## Service Components

### Personalization::SnapshotBuilder

**Purpose**: Build sanitized user context for personalization planning.

**Input**:
```ruby
SnapshotBuilder.call(
  user_id: 123,                    # integer, optional
  session_id: "sess_abc123",       # string, required
  page: "home",                    # string, required
  pid: 456,                        # integer, optional (PDP context)
  region: "Nairobi",               # string, required
  geohash6: "s17h0m",             # string, optional
  pickup_only: true,               # boolean, optional
  search_type: "text",             # string, optional
  search_term: "blue dress"        # string, optional
)
```

**Output**:
```ruby
{
  "user_id" => 123,
  "session_id" => "sess_abc123",
  "page" => "home",
  "pid" => 456,
  "search" => { "type" => "text", "term" => "blue dress" },
  "last_search" => "previous search term",
  "last_view_category" => "Women's Fashion",
  "recent_add_to_cart" => true,
  "views_in_last_10m" => 5,
  "minutes_since_last_action" => 2.5,
  "region" => "Nairobi",
  "geohash6" => "s17h0m",
  "pickup_only" => true
}
```

**Data Sources**:
- Recent events (last 15 minutes) from Events table
- Micro-state from Redis (if implemented)
- User profiles from user_profiles table (if implemented)

### Personalization::PlannerSelector

**Purpose**: Choose between Operator (LLM) and Control planning strategies.

**Input**:
```ruby
PlannerSelector.call(
  snapshot: { /* snapshot hash */ },
  fingerprint: "sha256_hash",
  enable_operator: true
)
```

**Output**:
```ruby
{
  plan_id: "operator_v1",
  query_pack: {
    "queries" => [
      {
        "phrase" => "blue dress",
        "category" => "Women's Fashion",
        "weight" => 1.0,
        "role" => "search"
      }
    ],
    "constraints" => {
      "pickup_only" => true,
      "region" => "Nairobi"
    },
    "prompt_version" => "qp_operator_v1",
    "model_version" => "gpt-4"
  },
  source: :operator  # or :control
}
```

**Control Plan Fallback**:
```ruby
{
  plan_id: "control_v1",
  query_pack: {
    "queries" => [
      {
        "phrase" => "trending",
        "weight" => 1.0,
        "role" => "trending"
      }
    ],
    "constraints" => { "pickup_only" => false, "region" => "Nairobi" },
    "prompt_version" => "qp_control_v1",
    "model_version" => "na"
  },
  source: :control
}
```

### Personalization::VectorSearch

**Purpose**: Execute ANN queries against product embeddings.

**Input (Text Search)**:
```ruby
VectorSearch.call(
  query_pack: {
    "queries" => [
      {
        "phrase" => "blue summer dress",
        "category" => "Women's Fashion",
        "weight" => 1.5,
        "role" => "search"
      }
    ],
    "constraints" => {
      "pickup_only" => true,
      "region" => "Nairobi"
    }
  },
  limit: 100
)
```

**Input (Direct Vector)**:
```ruby
VectorSearch.by_vector(
  vector: [0.1, -0.2, 0.3, ...], # Array of 1536 floats
  limit: 50,
  constraints: {
    "pickup_only" => false,
    "region" => "Nairobi"
  }
)
```

**Output**:
```ruby
[
  {
    id: 123,
    matched_phrase: "blue summer dress",
    vec_score: 0.87,
    weight: 1.5,
    role: "search"
  },
  {
    id: 456,
    matched_phrase: "blue summer dress", 
    vec_score: 0.82,
    weight: 1.5,
    role: "search"
  }
]
```

**Constraints Applied**:
- `stock > 0`
- `moderation_status = 'approved'`
- `pickup_ready = TRUE` (if pickup_only)
- Category filter (if specified)
- Region filter (if specified)

### Personalization::SearchTextRetriever

**Purpose**: Handle text search queries.

**Input**:
```ruby
SearchTextRetriever.call(
  term: "blue dress",
  constraints: {
    "pickup_only" => true,
    "region" => "Nairobi"
  },
  limit: 100
)
```

**Output**: Same format as VectorSearch, with role set to "search".

### Personalization::SearchImageRetriever

**Purpose**: Handle image search queries with URL allowlist.

**Input**:
```ruby
SearchImageRetriever.call(
  image_url: "https://res.cloudinary.com/demo/image/upload/sample.jpg",
  constraints: {
    "pickup_only" => false,
    "region" => "Nairobi"
  },
  limit: 100
)
```

**Output**:
```ruby
[
  {
    id: 789,
    vec_score: 0.91,
    weight: 1.0,
    role: "image_search",
    matched_phrase: "image_query"
  }
]
```

**Validation**:
- URL must pass `ImageEmbedder.allowed_host?` check
- Host must be in CLOUDINARY_HOST_ALLOWLIST

### Personalization::ImageEmbedder

**Purpose**: Generate embeddings for image URLs with security controls.

**Input**:
```ruby
ImageEmbedder.embed_image("https://res.cloudinary.com/demo/image/upload/sample.jpg")
```

**Output**:
```ruby
[0.1, -0.2, 0.3, ...] # Array of 1536 floats
```

**Errors**:
- `ImageEmbedder::Error` if host not allowed
- `ImageEmbedder::Error` if embedding fails

**Allowlist Check**:
```ruby
ImageEmbedder.allowed_host?("https://res.cloudinary.com/demo/image/upload/sample.jpg")
# => true if host ends with any domain in CLOUDINARY_HOST_ALLOWLIST
```

### Personalization::Ranker

**Purpose**: Apply business rules and diversity constraints to candidate pools.

**Input**:
```ruby
Ranker.call(
  pool: [
    { id: 123, vec_score: 0.9, weight: 1.0, role: "search" },
    { id: 456, vec_score: 0.8, weight: 1.2, role: "trending" }
  ],
  region: "Nairobi"
)
```

**Output**:
```ruby
[
  {
    id: 123,
    final_score: 0.9,
    reason: "Close to the styles you viewed",
    matched_phrase: "blue dress",
    vec_score: 0.9,
    weight: 1.0,
    role: "search"
  }
]
```

**Business Rules Applied**:
- Merchant cap: ≤3 items per shop
- Score normalization and position weighting
- Diversity filtering
- Result limit: ≤200 items

### Personalization::SlateWriter

**Purpose**: Persist feed and exposure records to database.

**Input**:
```ruby
SlateWriter.persist!(
  snapshot: { /* snapshot hash */ },
  fingerprint: "sha256_hash",
  ranked_items: [ /* ranked results */ ],
  ttl_seconds: 300,
  versions: {
    prompt_version: "qp_operator_v1",
    model_version: "gpt-4",
    index_version: "vec_2025_01_15"
  },
  plan_id: "operator_v1"
)
```

**Output**:
```ruby
[
  feed,        # Feed record
  reasons_map  # Hash of product_id => reason string
]
```

**Database Records Created**:
- 1 Feed record with feed_uid, plan_id, versions, constraints
- N FeedItem records (server-truth exposures) with position, scores, reasons

### Personalization::FingerprintCache

**Purpose**: Cache feed results by content fingerprint.

**Input (Store)**:
```ruby
FingerprintCache.store!(
  fingerprint: "sha256_hash",
  feed: feed_record,
  items: ["123", "456", "789"],
  reasons: { "123" => "trending", "456" => "search match" },
  ttl_seconds: 300
)
```

**Input (Fetch)**:
```ruby
FingerprintCache.reuse_feed(
  fingerprint: "sha256_hash",
  ttl_seconds: 300
)
```

**Output (Cache Hit)**:
```ruby
{
  feed: feed_record,
  items: ["123", "456", "789"],
  reasons: { "123" => "trending", "456" => "search match" },
  plan_id: "operator_v1"
}
```

**Output (Cache Miss)**: `nil`

### Personalization::PlanCache

**Purpose**: Cache query plans by fingerprint.

**Input (Store)**:
```ruby
PlanCache.store!(
  fingerprint: "sha256_hash",
  plan: {
    plan_id: "operator_v1",
    query_pack: { /* query structure */ },
    source: :operator
  },
  ttl_seconds: 300
)
```

**Input (Fetch)**:
```ruby
PlanCache.fetch("sha256_hash")
```

**Output**: Plan hash or `nil`

## Data Flow Examples

### Home Feed Request

**Input**:
```
POST /api/feeds/start
{
  "page": "home",
  "session_id": "sess_123",
  "user_id": 456,
  "region": "Nairobi",
  "limit": 24
}
```

**Internal Flow**:
1. **Snapshot**: `{ user_id: 456, page: "home", region: "Nairobi", recent_add_to_cart: false, ... }`
2. **Fingerprint**: `"abc123def..."`
3. **Plan Cache**: Miss → PlannerSelector → Control plan
4. **VectorSearch**: Trending query → 200 candidates
5. **Ranker**: Apply diversity → 24 final items
6. **Response**: Sectioned feed with plan_id="control_v1"

### Text Search Request

**Input**:
```
POST /api/feeds/start
{
  "page": "home",
  "session_id": "sess_123",
  "region": "Nairobi",
  "searchType": "text",
  "searchTerm": "blue dress",
  "limit": 12
}
```

**Internal Flow**:
1. **Snapshot**: `{ search: { type: "text", term: "blue dress" }, ... }`
2. **Plan**: Intent shift detected → Operator call (if enabled)
3. **SearchTextRetriever**: Embed "blue dress" → ANN search → candidates
4. **Response**: Search results with plan_id and search context

### Image Search Request

**Input**:
```
POST /api/feeds/start
{
  "page": "home",
  "session_id": "sess_123",
  "region": "Nairobi",
  "searchType": "image",
  "imageUrl": "https://res.cloudinary.com/demo/image/upload/v1234/sample.jpg",
  "limit": 20
}
```

**Internal Flow**:
1. **Allowlist Check**: Validate Cloudinary host
2. **ImageEmbedder**: Fetch image → embed → vector
3. **SearchImageRetriever**: KNN search → candidates
4. **Response**: Visual similarity results

**Error Case** (Invalid Host):
```
422 Unprocessable Entity
{
  "error": "image_url host not allowed"
}
```

### Events Ingestion

**Input**:
```
POST /api/events
{
  "events": [
    {
      "event_id": "evt_123",
      "session_id": "sess_123", 
      "event_name": "product_click",
      "page": "home",
      "region": "Nairobi",
      "payload": {
        "feed_id": "feed_uuid",
        "plan_id": "operator_v1",
        "product_id": 789,
        "position": 3,
        "section": "grid"
      }
    }
  ]
}
```

**Processing**:
1. **Validation**: Check required fields, whitelist payload
2. **Reject**: Any payload containing `imageUrl`
3. **Store**: Upsert to events table (idempotent by event_id)
4. **Response**: Accept/reject counts

## Error Handling

### Graceful Degradation

**Operator Timeout**: Falls back to Control plan
**Vector Search Failure**: Returns empty results → triggers popular fallback
**Cache Failure**: Continues without cache
**Invalid Image URL**: Returns 422 with error message

### Fallback Feed

When primary search fails:
```ruby
{
  feed_id: "real_uuid",  # Not literal "fallback"
  plan_id: "control_fallback_v1",
  sections: [
    {
      id: "grid",
      reason: nil,
      products: [/* recent approved products */]
    }
  ],
  ttl_seconds: 60,
  is_cache_hit: false
}
```

## Performance Characteristics

### SLOs
- Feed p95: ≤ 1.0s
- Operator p95: ≤ 800ms  
- Plan cache hit: ≥ 70%
- Image embed p95: ≤ 250ms (after cache warm)

### Optimization Strategies
- Fingerprint-based plan caching (5-10min TTL)
- ANN query result pooling
- Lite product serialization (minimal fields)
- Async ETL processing
- Redis-based micro-state caching

## Security & Privacy

### PII Protection
- No PII in snapshots sent to Operator
- No `imageUrl` in stored analytics events
- User context sanitized to IDs/enums/buckets only

### Host Allowlist
- Image URLs validated against CLOUDINARY_HOST_ALLOWLIST
- Only trusted CDN domains accepted
- Fetch timeouts and size limits enforced

### Authentication
- JWT auth required for authenticated endpoints
- Anonymous users supported with session_id
- Rate limiting recommended (not implemented)

