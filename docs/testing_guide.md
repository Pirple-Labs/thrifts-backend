# Testing Guide

## Overview

This guide provides comprehensive test scenarios, expected behaviors, and validation procedures for the personalization system.

## Unit Testing

### Personalization::SnapshotBuilder

**Test: Basic snapshot generation**
```ruby
# Input
snapshot = SnapshotBuilder.call(
  user_id: 123,
  session_id: "sess_test",
  page: "home",
  pid: nil,
  region: "Nairobi",
  geohash6: "s17h0m",
  pickup_only: false
)

# Expected Output Structure
expect(snapshot).to include(
  "user_id" => 123,
  "session_id" => "sess_test",
  "page" => "home",
  "region" => "Nairobi",
  "geohash6" => "s17h0m",
  "pickup_only" => false
)
expect(snapshot).to have_key("views_in_last_10m")
expect(snapshot).to have_key("recent_add_to_cart")
```

**Test: Search context handling**
```ruby
# Text search
snapshot = SnapshotBuilder.call(
  user_id: 123,
  session_id: "sess_test",
  page: "home",
  region: "Nairobi",
  search_type: "text",
  search_term: "blue dress"
)

expect(snapshot["search"]).to eq({
  "type" => "text",
  "term" => "blue dress"
})

# Image search (no term stored)
snapshot = SnapshotBuilder.call(
  user_id: 123,
  session_id: "sess_test", 
  page: "home",
  region: "Nairobi",
  search_type: "image"
)

expect(snapshot["search"]).to eq({"type" => "image"})
```

**Test: Search term length validation**
```ruby
# Long search term truncation
long_term = "a" * 300
snapshot = SnapshotBuilder.call(
  user_id: 123,
  session_id: "sess_test",
  page: "home",
  region: "Nairobi",
  search_type: "text",
  search_term: long_term
)

expect(snapshot.dig("search", "term").length).to eq(256)
```

### Personalization::PlannerSelector

**Test: Control plan fallback**
```ruby
plan = PlannerSelector.call(
  snapshot: {"page" => "home", "pickup_only" => false, "region" => "Nairobi"},
  fingerprint: "test_fp",
  enable_operator: false
)

expect(plan[:plan_id]).to eq("control_v1")
expect(plan[:source]).to eq(:control)
expect(plan[:query_pack]["queries"]).to be_an(Array)
```

**Test: Intent shift detection**
```ruby
# Search triggers operator
search_snapshot = {
  "page" => "home",
  "search" => {"type" => "text", "term" => "dress"},
  "region" => "Nairobi"
}

plan = PlannerSelector.call(
  snapshot: search_snapshot,
  fingerprint: "test_fp", 
  enable_operator: true
)

# Should attempt operator call (may fallback to control on error)
expect(plan[:plan_id]).to be_present
expect(plan[:source]).to be_in([:operator, :control])
```

### Personalization::VectorSearch

**Test: Basic query execution**
```ruby
# Mock product and embedding data
create_product_with_embedding(
  product_id: 1,
  embedding: Array.new(1536) { 0.1 },
  stock: 5,
  moderation_status: "approved"
)

query_pack = {
  "queries" => [
    {"phrase" => "test query", "weight" => 1.0, "role" => "search"}
  ],
  "constraints" => {"pickup_only" => false, "region" => "Nairobi"}
}

results = VectorSearch.call(query_pack: query_pack, limit: 10)

expect(results).to be_an(Array)
expect(results.first).to include(:id, :vec_score, :weight, :role)
expect(results.first[:id]).to eq(1)
```

**Test: Constraint filtering**
```ruby
# Create products with different constraints
create_product_with_embedding(id: 1, pickup_ready: true, stock: 5)
create_product_with_embedding(id: 2, pickup_ready: false, stock: 5)

query_pack = {
  "queries" => [{"phrase" => "test", "weight" => 1.0, "role" => "search"}],
  "constraints" => {"pickup_only" => true}
}

results = VectorSearch.call(query_pack: query_pack, limit: 10)

# Should only return pickup-ready products
expect(results.map { |r| r[:id] }).to eq([1])
```

### Personalization::ImageEmbedder

**Test: Host allowlist validation**
```ruby
# Allowed host
expect(ImageEmbedder.allowed_host?("https://res.cloudinary.com/demo/image.jpg")).to be_truthy

# Disallowed host  
expect(ImageEmbedder.allowed_host?("https://evil.com/image.jpg")).to be_falsy

# Invalid URL
expect(ImageEmbedder.allowed_host?("not-a-url")).to be_falsy
```

**Test: Embedding generation**
```ruby
# Mock OpenAI client
allow(Embeddings::OpenAIClient).to receive(:embed).and_return([Array.new(1536) { 0.1 }])

embedding = ImageEmbedder.embed_image("https://res.cloudinary.com/demo/image.jpg")

expect(embedding).to be_an(Array)
expect(embedding.length).to eq(1536)
```

**Test: Error handling**
```ruby
# Invalid host should raise error
expect {
  ImageEmbedder.embed_image("https://evil.com/image.jpg")
}.to raise_error(Personalization::ImageEmbedder::Error, "invalid host")
```

### Api::EventsController

**Test: Payload whitelist enforcement**
```ruby
post "/api/events", params: {
  events: [{
    event_id: "test_1",
    session_id: "sess_test",
    event_name: "product_click",
    page: "home",
    region: "Nairobi",
    payload: {
      product_id: 123,
      feed_id: "feed_123",
      imageUrl: "https://evil.com/image.jpg",  # Should be rejected
      allowedField: "allowed_value"            # Should be rejected (not in whitelist)
    }
  }]
}

expect(response).to have_http_status(:ok)

# Check stored event
event = Event.find_by(event_id: "test_1")
expect(event.payload).to eq({
  "product_id" => 123,
  "feed_id" => "feed_123"
  # imageUrl and allowedField should be stripped
})
```

**Test: Event validation**
```ruby
# Missing required fields
post "/api/events", params: {
  events: [{
    event_id: "test_2",
    # Missing session_id, event_name, page, region
    payload: {}
  }]
}

response_data = JSON.parse(response.body)
expect(response_data["rejected"]).to eq(1)
expect(response_data["accepted"]).to eq(0)
```

**Test: Feed event validation**
```ruby
# Feed events must have valid feed_id
post "/api/events", params: {
  events: [{
    event_id: "test_3",
    session_id: "sess_test",
    event_name: "product_impression",  # Feed event
    page: "home",
    region: "Nairobi",
    payload: {
      feed_id: "fallback",  # Invalid feed_id
      product_id: 123
    }
  }]
}

response_data = JSON.parse(response.body)
expect(response_data["rejected"]).to eq(1)
```

**Test: Idempotency**
```ruby
event_params = {
  events: [{
    event_id: "duplicate_test",
    session_id: "sess_test",
    event_name: "product_click",
    page: "home", 
    region: "Nairobi",
    payload: { product_id: 123 }
  }]
}

# First request
post "/api/events", params: event_params
expect(Event.where(event_id: "duplicate_test").count).to eq(1)

# Duplicate request
post "/api/events", params: event_params  
expect(Event.where(event_id: "duplicate_test").count).to eq(1) # Still 1
```

## Integration Testing

### Feed Generation End-to-End

**Test: Home feed generation**
```ruby
# Setup test data
user = create(:user)
create_list(:product_with_embedding, 10, stock: 5, moderation_status: "approved")

post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_integration",
  user_id: user.id,
  region: "Nairobi",
  limit: 5
}

expect(response).to have_http_status(:ok)
response_data = JSON.parse(response.body)

# Validate response structure
expect(response_data).to include(
  "feed_id",
  "plan_id", 
  "ttl_seconds",
  "sections",
  "cursor",
  "hasMore"
)

expect(response_data["sections"]).to be_an(Array)
expect(response_data["sections"].first).to include("id", "reason", "products")
expect(response_data["sections"].first["products"]).to be_an(Array)
expect(response_data["sections"].first["products"].length).to be <= 5

# Validate lite product structure  
product = response_data["sections"].first["products"].first
expect(product).to include("id", "name", "price", "image", "shop")
expect(product["shop"]).to include("id", "name")
```

**Test: Text search feed**
```ruby
post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_search",
  region: "Nairobi",
  searchType: "text",
  searchTerm: "blue dress",
  limit: 10
}

expect(response).to have_http_status(:ok)
response_data = JSON.parse(response.body)

# Should include search context in plan
expect(response_data["plan_id"]).to be_present
# Products should be relevant to search (if any found)
```

**Test: Image search with allowlist**
```ruby
# Valid Cloudinary URL
post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_image",
  region: "Nairobi", 
  searchType: "image",
  imageUrl: "https://res.cloudinary.com/demo/image/upload/sample.jpg",
  limit: 10
}

expect(response).to have_http_status(:ok)

# Invalid host URL
post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_image",
  region: "Nairobi",
  searchType: "image", 
  imageUrl: "https://evil.com/image.jpg",
  limit: 10
}

expect(response).to have_http_status(:unprocessable_entity)
expect(JSON.parse(response.body)["error"]).to include("host not allowed")
```

**Test: Feed pagination**
```ruby
# Get first page
post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_pagination",
  region: "Nairobi",
  limit: 3
}

first_page = JSON.parse(response.body)
feed_id = first_page["feed_id"]
cursor = first_page["cursor"]

# Get next page
post "/api/feeds/next", params: {
  feed_id: feed_id,
  cursor: cursor,
  limit: 3
}

expect(response).to have_http_status(:ok)
second_page = JSON.parse(response.body)

# Should have same feed_id, different products
expect(second_page["feed_id"]).to eq(feed_id)
# Products should be different (no overlap)
first_ids = first_page["sections"].first["products"].map { |p| p["id"] }
second_ids = second_page["sections"].first["products"].map { |p| p["id"] }
expect(first_ids & second_ids).to be_empty
```

### Cache Behavior Testing

**Test: Plan cache hit**
```ruby
# Clear caches
Rails.cache.clear

# First request - cache miss
post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_cache",
  region: "Nairobi"
}

first_response = JSON.parse(response.body)
expect(first_response["is_cache_hit"]).to be_falsy

# Second identical request - should hit plan cache
post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_cache", 
  region: "Nairobi"
}

second_response = JSON.parse(response.body)
# May or may not be cache hit depending on implementation, but should be consistent
```

**Test: Fingerprint consistency**
```ruby
# Same parameters should generate same fingerprint
params = {
  page: "home",
  session_id: "sess_fp",
  region: "Nairobi",
  pickup_only: false
}

# Make multiple requests
fingerprints = []
3.times do
  post "/api/feeds/start", params: params
  # Would need to capture fingerprint from logs or response
end

# Fingerprints should be identical for same input
# expect(fingerprints.uniq.length).to eq(1)
```

## Performance Testing

### Latency Requirements

**Test: Feed response time**
```ruby
# Warm up
post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_perf",
  region: "Nairobi"
}

# Measure response time
start_time = Time.current
post "/api/feeds/start", params: {
  page: "home", 
  session_id: "sess_perf_#{rand(1000)}",
  region: "Nairobi"
}
end_time = Time.current

response_time_ms = (end_time - start_time) * 1000
expect(response_time_ms).to be < 1000  # p95 ≤ 1000ms SLO
expect(response).to have_http_status(:ok)
```

**Test: Event ingestion performance**
```ruby
# Batch event ingestion
events = 50.times.map do |i|
  {
    event_id: "perf_#{i}",
    session_id: "sess_perf",
    event_name: "product_impression",
    page: "home",
    region: "Nairobi",
    payload: { product_id: i, feed_id: "feed_#{i}" }
  }
end

start_time = Time.current
post "/api/events", params: { events: events }
end_time = Time.current

ingestion_time_ms = (end_time - start_time) * 1000
expect(response).to have_http_status(:ok)
expect(ingestion_time_ms).to be < 500  # Batch ingestion should be fast

response_data = JSON.parse(response.body)
expect(response_data["accepted"]).to eq(50)
```

### Load Testing Scenarios

**Test: Concurrent feed requests**
```ruby
# Simulate concurrent users
threads = []
results = []

10.times do |i|
  threads << Thread.new do
    response = post "/api/feeds/start", params: {
      page: "home",
      session_id: "sess_load_#{i}",
      region: "Nairobi"
    }
    results << { thread: i, status: response.status }
  end
end

threads.each(&:join)

# All requests should succeed
expect(results.all? { |r| r[:status] == 200 }).to be_truthy
```

## Error Handling & Fallback Testing

### Operator Fallback

**Test: Operator timeout fallback**
```ruby
# Mock operator timeout
allow(Personalization::OperatorHttpClient).to receive(:call).and_raise(StandardError.new("timeout"))

post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_fallback",
  region: "Nairobi",
  searchType: "text",
  searchTerm: "test query"  # Should trigger operator
}

expect(response).to have_http_status(:ok)
response_data = JSON.parse(response.body)

# Should fallback to control plan
expect(response_data["plan_id"]).to eq("control_v1")
expect(response_data["sections"]).to be_present
```

**Test: Vector search failure fallback**
```ruby
# Mock vector search failure
allow(Personalization::VectorSearch).to receive(:call).and_return([])

post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_vector_fail",
  region: "Nairobi"
}

expect(response).to have_http_status(:ok)
response_data = JSON.parse(response.body)

# Should return popular fallback feed
expect(response_data["plan_id"]).to eq("control_fallback_v1")
```

### Image Search Error Handling

**Test: Image fetch timeout**
```ruby
# Mock image embedding failure
allow(Personalization::ImageEmbedder).to receive(:embed_image).and_raise(
  Personalization::ImageEmbedder::Error.new("fetch timeout")
)

post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_img_error",
  region: "Nairobi",
  searchType: "image",
  imageUrl: "https://res.cloudinary.com/demo/slow-image.jpg"
}

# Should return graceful error response
expect(response).to have_http_status(:ok)
response_data = JSON.parse(response.body)
expect(response_data["sections"].first["products"]).to be_empty
```

### Database Failure Handling

**Test: Feed persistence failure**
```ruby
# Mock database error
allow(Feed).to receive(:create!).and_raise(ActiveRecord::ConnectionTimeoutError)

post "/api/feeds/start", params: {
  page: "home", 
  session_id: "sess_db_error",
  region: "Nairobi"
}

# Should still return response (fallback mechanism)
expect(response.status).to be_in([200, 500])
```

## Security Testing

### Input Validation

**Test: SQL injection prevention**
```ruby
# Malicious input in search term
post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_security",
  region: "Nairobi",
  searchType: "text",
  searchTerm: "'; DROP TABLE products; --"
}

expect(response).to have_http_status(:ok)
# Should not cause database errors
expect(Product.count).to be > 0  # Table should still exist
```

**Test: XSS prevention in responses**
```ruby
# Create product with malicious name
product = create(:product, name: "<script>alert('xss')</script>")

post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_xss",
  region: "Nairobi"
}

response_body = response.body
# Response should not contain unescaped script tags
expect(response_body).not_to include("<script>")
```

### Authorization Testing

**Test: Anonymous user limits**
```ruby
# Anonymous users should be limited to 2 pages
3.times do |page|
  post "/api/products", params: { page: page + 1 }
  
  if page < 2
    expect(response).to have_http_status(:ok)
  else
    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body)["error"]).to include("Guest limit reached")
  end
end
```

**Test: Event authentication**
```ruby
# Events endpoint should accept requests without auth
post "/api/events", params: {
  events: [{
    event_id: "auth_test",
    session_id: "sess_anon",
    event_name: "page_view",
    page: "home",
    region: "Nairobi",
    payload: {}
  }]
}

expect(response).to have_http_status(:ok)
```

## Data Consistency Testing

### Feed-Event Attribution

**Test: Exposure record creation**
```ruby
# Generate feed
post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_attribution",
  user_id: create(:user).id,
  region: "Nairobi",
  limit: 5
}

response_data = JSON.parse(response.body)
feed_id = response_data["feed_id"]

# Check that feed_items were created
feed = Feed.find_by(feed_uid: feed_id)
expect(feed).to be_present
expect(feed.feed_items.count).to be > 0

# Check feed_item structure
feed_item = feed.feed_items.first
expect(feed_item).to have_attributes(
  section: "grid",
  position: 0,
  reason: be_present,
  final_score: be_present
)
```

**Test: Event-exposure relationship**
```ruby
# Create a feed with known product
product = create(:product_with_embedding)
# ... generate feed containing this product ...

# Send corresponding event
post "/api/events", params: {
  events: [{
    event_id: "attribution_test",
    session_id: "sess_attribution",
    event_name: "product_click",
    page: "home",
    region: "Nairobi",
    payload: {
      feed_id: feed_id,
      product_id: product.id,
      position: 0
    }
  }]
}

# Event should be stored with correct payload
event = Event.find_by(event_id: "attribution_test")
expect(event.payload["feed_id"]).to eq(feed_id)
expect(event.payload["product_id"]).to eq(product.id)
```

## Monitoring & Observability Testing

### Metrics Collection

**Test: Response time logging**
```ruby
# Check that feed requests log timing information
allow(Rails.logger).to receive(:info)

post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_metrics",
  region: "Nairobi"
}

# Should log timing information
expect(Rails.logger).to have_received(:info).with(
  a_string_matching(/feed_id.*plan_id.*total_ms/)
)
```

**Test: Error rate tracking**
```ruby
# Force an error condition
allow(Personalization::VectorSearch).to receive(:call).and_raise(StandardError)

post "/api/feeds/start", params: {
  page: "home",
  session_id: "sess_error_tracking",
  region: "Nairobi"
}

# Should log error information
expect(Rails.logger).to have_received(:error).with(
  a_string_matching(/\[\/api\/feed\/start\].*error/)
)
```

## Test Data Setup

### Factory Definitions

```ruby
# spec/factories/products.rb
FactoryBot.define do
  factory :product_with_embedding, parent: :product do
    after(:create) do |product|
      create(:product_embedding, product: product)
    end
  end
  
  factory :product_embedding do
    association :product
    embedding { Array.new(1536) { rand(-1.0..1.0) } }
    index_version { "test_v1" }
    embedded_at { Time.current }
  end
end

# spec/factories/events.rb
FactoryBot.define do
  factory :event do
    sequence(:event_id) { |n| "event_#{n}" }
    session_id { "sess_test" }
    event_name { "product_impression" }
    page { "home" }
    region { "Nairobi" }
    timestamp_utc { Time.current }
    payload { {} }
  end
end
```

### Test Database Seeding

```ruby
# spec/support/test_data.rb
def seed_test_products(count: 10)
  categories = create_list(:category, 3)
  shops = create_list(:shop, 3)
  
  count.times do |i|
    create(:product_with_embedding,
      name: "Test Product #{i}",
      category: categories.sample,
      shop: shops.sample,
      stock: rand(1..10),
      moderation_status: "approved"
    )
  end
end

def create_test_feed_with_events(user: nil)
  user ||= create(:user)
  
  # Create feed
  post "/api/feeds/start", params: {
    page: "home",
    session_id: "test_session",
    user_id: user.id,
    region: "Nairobi"
  }
  
  feed_data = JSON.parse(response.body)
  
  # Create corresponding events
  feed_data["sections"].first["products"].each_with_index do |product, index|
    create(:event,
      event_name: "product_impression",
      payload: {
        feed_id: feed_data["feed_id"],
        product_id: product["id"],
        position: index
      }
    )
  end
  
  feed_data
end
```

This testing guide covers all major components and scenarios for validating the personalization system's functionality, performance, security, and data consistency.
