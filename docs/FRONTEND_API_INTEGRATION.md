# Frontend API Integration Guide

## 🎯 Personalized Feeds API

The Rails backend now provides a fully functional API endpoint for AI-powered personalized product recommendations.

### 📍 Endpoint

```
GET /api/demo/personalized-feed
```

### 🔧 Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `page` | string | No | `"home"` | Page context (home, search, pdp, profile) |
| `user_id` | integer | No | `1` | User ID for personalization |
| `session_id` | string | No | auto-generated | Session identifier |
| `region` | string | No | `"ke"` | Geographic region |
| `pickup_only` | boolean | No | `false` | Filter for pickup-only items |
| `force_fresh` | boolean | No | `false` | Bypass cache for fresh LLM plans |

### 📊 Response Format

```json
{
  "demo_info": {
    "page": "home",
    "user_id": "1",
    "session_id": "demo_session_abc123",
    "region": "ke",
    "pickup_only": false,
    "profile_hash": "00___1000_1000_00",
    "intent_drift": false,
    "plan_source": "llm",
    "plan_id": "plan_2025-09-05T09:21:33Z_ab14cd09_home_v1"
  },
  "feed": {
    "feed_id": "uuid-string",
    "plan_id": "plan_2025-09-05T09:21:33Z_ab14cd09_home_v1",
    "ttl_seconds": 172800,
    "sections": [
      {
        "id": "lookalikes",
        "title": "Lookalikes",
        "reason": "Similar items to enhance your choices.",
        "products": [
          {
            "id": 270,
            "name": "Kitchen 35",
            "price": "170.99",
            "image": "https://res.cloudinary.com/.../image.jpg",
            "main_image": "https://res.cloudinary.com/.../main.jpg",
            "supplementary_images": "https://res.cloudinary.com/.../img1.jpg https://res.cloudinary.com/.../img2.jpg",
            "shop": {
              "id": 1,
              "name": "Jesse's Shop",
              "store_logo_url": null
            }
          }
        ],
        "count": 10,
        "metadata": {
          "pre_guard_candidates": 15,
          "guardrail_drops": {},
          "retrieval_latency": 0,
          "guardrails_latency": 0,
          "coordination_latency": 0,
          "total_latency": 0
        }
      }
    ],
    "total_products": 13,
    "total_sections": 4
  },
  "profile_analysis": {
    "price_band": "low",
    "top_categories": [],
    "brand_preferences": [],
    "shop_preferences": [],
    "freshness_preference": 0.5,
    "diversity_preference": 0.5
  },
  "snapshot_analysis": {
    "region": "ke",
    "pickup_only": false,
    "recent_views": 0,
    "recent_cart_activity": false,
    "activity_level": "dormant",
    "last_search": null
  }
}
```

### 🚀 Example Usage

#### Basic Request
```bash
curl "http://localhost:3000/api/demo/personalized-feed?page=home&user_id=1&region=ke"
```

#### Force Fresh LLM Plan
```bash
curl "http://localhost:3000/api/demo/personalized-feed?page=home&user_id=1&region=ke&force_fresh=true"
```

#### JavaScript/Fetch Example
```javascript
const response = await fetch('/api/demo/personalized-feed?page=home&user_id=1&region=ke&force_fresh=true');
const data = await response.json();

console.log(`Plan Source: ${data.demo_info.plan_source}`); // "llm"
console.log(`Total Products: ${data.feed.total_products}`); // 13
console.log(`Sections: ${data.feed.total_sections}`); // 4

// Display products from each section
data.feed.sections.forEach(section => {
  console.log(`Section: ${section.title}`);
  console.log(`Reason: ${section.reason}`);
  section.products.forEach(product => {
    console.log(`- ${product.name}: $${product.price}`);
  });
});
```

### 🎨 Frontend Integration Tips

#### 1. Section Rendering
```javascript
// Render each section with AI-generated reasoning
data.feed.sections.forEach(section => {
  if (section.products.length > 0) {
    renderSection({
      title: section.title,
      reason: section.reason, // AI-generated explanation
      products: section.products
    });
  }
});
```

#### 2. Product Display
```javascript
// Each product includes complete data for display
section.products.forEach(product => {
  renderProduct({
    id: product.id,
    name: product.name,
    price: product.price,
    image: product.main_image,
    shop: product.shop.name
  });
});
```

#### 3. Caching Strategy
- Use `force_fresh=true` for testing new LLM plans
- Normal requests use cached plans for performance
- Plans have TTL of 48 hours (`ttl_seconds: 172800`)

#### 4. Error Handling
```javascript
try {
  const response = await fetch('/api/demo/personalized-feed?page=home&user_id=1');
  const data = await response.json();
  
  if (data.error) {
    console.error('API Error:', data.message);
    // Fallback to default content
  } else {
    // Render personalized content
    renderPersonalizedFeed(data.feed);
  }
} catch (error) {
  console.error('Network Error:', error);
  // Show offline/error state
}
```

### 🔍 Plan Sources

- **`"llm"`**: AI-generated plans with intelligent reasoning
- **`"control"`**: Fallback plans when LLM is unavailable
- **`"operator"`**: Legacy operator plans

### 📈 Performance Metrics

Each section includes metadata for monitoring:
- `retrieval_latency`: Time to fetch products
- `guardrails_latency`: Time for quality filtering
- `coordination_latency`: Time for merchant balancing
- `total_latency`: End-to-end section processing time

### 🎯 AI-Powered Features

1. **Intelligent Section Reasoning**: Each section includes AI-generated explanations
2. **Dynamic Product Selection**: Products chosen based on user behavior and preferences
3. **Contextual Recommendations**: Different sections for different user intents
4. **Real-time Personalization**: Fresh plans generated based on current user state

### 🔧 Development Setup

1. **Start Rails Server**: `rails server`
2. **Start Python Operator**: `rails operator:start_mock`
3. **Test API**: Use the examples above
4. **Monitor Logs**: Check `log/development.log` for debugging

### 📝 Notes

- The API is currently in demo mode (no authentication required)
- All user IDs are valid for testing
- LLM plans are generated by the Python Operator service
- Response format is optimized for frontend consumption
- Images are served from Cloudinary CDN

---

**Status**: ✅ Ready for Frontend Integration
**Last Updated**: September 6, 2025

