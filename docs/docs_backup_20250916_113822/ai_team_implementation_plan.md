# AI Team Implementation Plan: Playbook-Based Personalization System

## 🎯 **Overview**

The Rails backend has implemented a complete **Playbook-based personalization system** that requires AI-generated playbooks every 48 hours. This document provides the AI team with detailed implementation instructions, sample requests, and expected outputs.

## 🏗️ **System Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                    AI SERVICE (48h)                        │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │ Playbook        │    │ PlaybookGenerator               │ │
│  │ Generation      │───▶│ - User Context Building         │ │
│  │ (Every 48h)     │    │ - AI Service Integration        │ │
│  └─────────────────┘    │ - Response Validation           │ │
└─────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                  RAILS BACKEND (Real-time)                 │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │ Playbook        │    │ PlaybookExecutor                │ │
│  │ Storage         │───▶│ - Module Execution              │ │
│  │ (PostgreSQL)    │    │ - Product Retrieval             │ │
│  └─────────────────┘    │ - Placement Optimization        │ │
└─────────────────────────────────────────────────────────────┘
```

## 📋 **AI Team Responsibilities**

### **Core Task: Generate 48-Hour Playbooks**
- **Frequency**: Every 48 hours per user/cohort
- **Input**: Rich user context with behavioral data
- **Output**: Strategic playbook with module definitions
- **No Runtime Calls**: AI never called during user interactions

### **Key Requirements**
1. **Strategic Planning**: Generate high-level rules, not per-item rankings
2. **48-Hour Validity**: Playbooks must be valid for 48 hours
3. **Page-Specific**: Different playbooks for Home, PDP, Wishlist, Checkout, Profile
4. **Conversion Optimized**: Focus on conversion potential and placement
5. **Reusable Sections**: Generate sections that can be used across pages

## 🔌 **API Integration**

### **Endpoint**: `POST /operator/query-pack`
- **URL**: `http://localhost:8000/operator/query-pack`
- **Method**: POST
- **Content-Type**: application/json
- **Headers**: 
  - `X-Plan-DSL-Version: 3.0`
  - `X-Request-Id: playbook_{playbook_id}_{timestamp}`

### **Request Format**
```json
{
  "user_context": {
    "user_id": 123,
    "page": "home",
    "region": "ke",
    "timestamp": "2025-01-15T10:25:00Z",
    "behavioral_patterns": {
      "search_to_browse": true,
      "category_hopping": false,
      "price_exploration": true,
      "brand_loyalty": 0.3,
      "engagement_velocity": 2.5
    },
    "micro_events": [
      {
        "event_type": "product_view",
        "product": {
          "name": "White Nike Air Max",
          "category": "sneakers",
          "brand": "Nike",
          "price": 150,
          "style": "athletic",
          "color": "white"
        },
        "timestamp": "2025-01-15T10:20:00Z",
        "weight": 1.0,
        "context": {
          "page": "home",
          "position": 3
        }
      }
    ],
    "meso_events": [
      {
        "event_type": "search",
        "search_term": "white sneakers",
        "timestamp": "2025-01-15T10:15:00Z",
        "weight": 0.8
      }
    ],
    "macro_events": [
      {
        "event_type": "purchase",
        "product": {
          "name": "Black Adidas Stan Smith",
          "category": "sneakers",
          "brand": "Adidas",
          "price": 120
        },
        "timestamp": "2025-01-10T14:30:00Z",
        "weight": 2.0
      }
    ]
  },
  "ai_instructions": {
    "task": "generate_conversion_playbook",
    "requirements": {
      "page": "home",
      "max_sections": 6,
      "conversion_optimized": true,
      "reusable_sections": true,
      "search_strategies": true,
      "placement_suggestions": true,
      "conversion_rating": true
    }
  }
}
```

### **Expected Response Format**
```json
{
  "metadata": {
    "ai_generated": true,
    "conversion_optimized": true,
    "section_count": 4,
    "timestamp": "2025-01-15T10:25:00Z",
    "model_version": "gpt-4-turbo",
    "prompt_version": "playbook_v3.0",
    "cost_usd": 0.0023,
    "duration_ms": 1250
  },
  "personalized_sections": [
    {
      "id": "trending_nike_sneakers",
      "title": "Trending Nike Sneakers You'll Love",
      "type": "trending",
      "conversion_potential": "high",
      "placement_suggestions": ["home_top", "pdp_below", "wishlist_engagement"],
      "search_strategy": {
        "algorithm": "trending",
        "filters": {
          "brand": "Nike",
          "category": "sneakers",
          "color": "white",
          "style": "athletic"
        },
        "keywords": ["Nike sneakers athletic", "white sneakers"],
        "time_window": "7d"
      }
    },
    {
      "id": "more_white_sneakers",
      "title": "More White Sneakers Like This",
      "type": "similar",
      "conversion_potential": "medium",
      "placement_suggestions": ["pdp_similar", "home_middle", "checkout_related"],
      "search_strategy": {
        "algorithm": "similarity",
        "filters": {
          "color": "white",
          "price_range": [99, 199],
          "reference_product": "White Nike Air Max",
          "style": "athletic"
        },
        "keywords": ["White Nike Air Max", "similar white sneakers"],
        "time_window": null
      }
    },
    {
      "id": "complete_sneakers",
      "title": "Complete Your Sneakers",
      "type": "complementary",
      "conversion_potential": "high",
      "placement_suggestions": ["pdp_completion", "checkout_upsell", "home_bottom"],
      "search_strategy": {
        "algorithm": "complementary",
        "filters": {
          "category": "sneakers",
          "reference_product": "White Nike Air Max",
          "style": "athletic"
        },
        "keywords": ["athletic wear", "sneakers accessories", "sports clothing"],
        "time_window": null
      }
    },
    {
      "id": "discovery_grid",
      "title": "Discover New Styles",
      "type": "discovery",
      "conversion_potential": "high",
      "placement_suggestions": ["home_top", "home_middle", "wishlist_engagement"],
      "search_strategy": {
        "algorithm": "diversity",
        "filters": {
          "diversity_boost": true,
          "excluded_products": ["White Nike Air Max"]
        },
        "keywords": ["fashion trends", "new arrivals", "style inspiration"],
        "time_window": null
      }
    }
  ],
  "user_insights": {
    "behavioral_patterns": ["price_explorer", "brand_loyalty_nike"],
    "conversion_triggers": ["trending_items", "similar_products", "completion"],
    "intent": "browsing_sneakers",
    "primary_interests": ["Nike", "sneakers", "white color", "athletic style"]
  }
}
```

## 📄 **Page-Specific Requirements**

### **🏠 Home Page**
- **Focus**: Discovery-heavy with personalized trending strip
- **Structure**: Trending strip at top + discovery grid + dynamic injections
- **Key Modules**: `personalized_trending`, `discovery_grid`, `dynamic_injections`
- **Max Sections**: 6

### **🛍️ PDP (Product Detail Page)**
- **Focus**: Product decision support with complementary discovery
- **Structure**: Complements strip + similar items grid + optional injection
- **Key Modules**: `complete_the_look`, `similar_items_grid`, `optional_injection`
- **Max Sections**: 3

### **❤️ Wishlist Page**
- **Focus**: Reactivate interest in saved items
- **Structure**: Saved items grid + price alerts + complements + similar
- **Key Modules**: `price_drop_on_saved`, `complete_the_look_saved`, `similar_to_saved`
- **Max Sections**: 4

### **🛒 Checkout Page**
- **Focus**: Low-friction AOV lift without distraction
- **Structure**: Order summary + compact add-ons + bundle upgrade
- **Key Modules**: `compact_addon`, `bundle_upgrade`
- **Max Sections**: 2

### **👤 Profile Page**
- **Focus**: Identity-based personalization with loyalty and exploration
- **Structure**: Picks today + new from brands + continue browsing + exploration
- **Key Modules**: `your_picks_today`, `new_from_brands`, `continue_browsing`, `exploration_boost`
- **Max Sections**: 4

## 🎯 **Search Strategy Algorithms**

### **Available Algorithms**
1. **`trending`**: Popular items in time window
2. **`similarity`**: Similar to reference product
3. **`complementary`**: Complements reference product
4. **`diversity`**: Diverse recommendations
5. **`completion`**: Complete user's intent
6. **`new_arrivals`**: Recently added items
7. **`price_change`**: Items with price changes
8. **`stock_replenishment`**: Back in stock items

### **Filter Types**
- **Brand**: `"brand": "Nike"`
- **Category**: `"category": "sneakers"`
- **Color**: `"color": "white"`
- **Style**: `"style": "athletic"`
- **Price Range**: `"price_range": [99, 199]`
- **Reference Product**: `"reference_product": "White Nike Air Max"`
- **Excluded Products**: `"excluded_products": ["product1", "product2"]`
- **Search Terms**: `"keywords": ["Nike sneakers", "white sneakers"]`
- **Time Window**: `"time_window": "7d"`

## 🔍 **Sample Requests by Page**

### **Home Page Request**
```json
{
  "user_context": {
    "user_id": 123,
    "page": "home",
    "region": "ke",
    "behavioral_patterns": {
      "search_to_browse": true,
      "category_hopping": false,
      "price_exploration": true,
      "brand_loyalty": 0.3,
      "engagement_velocity": 2.5
    },
    "micro_events": [
      {
        "event_type": "product_view",
        "product": {
          "name": "White Nike Air Max",
          "category": "sneakers",
          "brand": "Nike",
          "price": 150,
          "style": "athletic",
          "color": "white"
        },
        "timestamp": "2025-01-15T10:20:00Z",
        "weight": 1.0
      }
    ]
  },
  "ai_instructions": {
    "task": "generate_conversion_playbook",
    "requirements": {
      "page": "home",
      "max_sections": 6,
      "conversion_optimized": true,
      "reusable_sections": true,
      "search_strategies": true,
      "placement_suggestions": true
    }
  }
}
```

### **PDP Request**
```json
{
  "user_context": {
    "user_id": 123,
    "page": "pdp",
    "region": "ke",
    "current_product": {
      "name": "White Nike Air Max",
      "category": "sneakers",
      "brand": "Nike",
      "price": 150,
      "style": "athletic",
      "color": "white"
    },
    "behavioral_patterns": {
      "price_exploration": true,
      "brand_loyalty": 0.3
    }
  },
  "ai_instructions": {
    "task": "generate_conversion_playbook",
    "requirements": {
      "page": "pdp",
      "max_sections": 3,
      "conversion_optimized": true,
      "reusable_sections": true,
      "search_strategies": true,
      "placement_suggestions": true
    }
  }
}
```

### **Wishlist Request**
```json
{
  "user_context": {
    "user_id": 123,
    "page": "wishlist",
    "region": "ke",
    "saved_items": [
      {
        "name": "White Nike Air Max",
        "category": "sneakers",
        "brand": "Nike",
        "price": 150,
        "saved_at": "2025-01-10T14:30:00Z"
      }
    ],
    "behavioral_patterns": {
      "price_exploration": true,
      "brand_loyalty": 0.3
    }
  },
  "ai_instructions": {
    "task": "generate_conversion_playbook",
    "requirements": {
      "page": "wishlist",
      "max_sections": 4,
      "conversion_optimized": true,
      "reusable_sections": true,
      "search_strategies": true,
      "placement_suggestions": true
    }
  }
}
```

## 🎨 **Personalization Guidelines**

### **Title Generation**
- **Personalized**: "Trending Nike Sneakers You'll Love"
- **Contextual**: "More White Sneakers Like This"
- **Action-Oriented**: "Complete Your Sneakers"
- **Discovery**: "Discover New Styles"

### **Conversion Potential**
- **`high`**: Trending items, complements, discovery
- **`medium`**: Similar items, price drops
- **`low`**: Diversity, exploration

### **Placement Suggestions**
- **Home**: `home_top`, `home_middle`, `home_bottom`, `home_discovery`, `home_injection`
- **PDP**: `pdp_below_gallery`, `pdp_below_details`, `pdp_injection`
- **Wishlist**: `wishlist_above_grid`, `wishlist_after_row_1`, `wishlist_below_grid`
- **Checkout**: `checkout_below_order`, `checkout_below_addon`
- **Profile**: `profile_top`, `profile_mid_1`, `profile_mid_2`, `profile_bottom`

## 🚨 **Error Handling**

### **Validation Errors**
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request format",
    "details": {
      "field": "user_context.user_id",
      "reason": "required_field_missing"
    }
  }
}
```

### **AI Generation Errors**
```json
{
  "error": {
    "code": "AI_GENERATION_ERROR",
    "message": "Failed to generate playbook",
    "details": {
      "reason": "insufficient_user_data",
      "fallback_used": true
    }
  }
}
```

## 📊 **Performance Requirements**

### **Latency Targets**
- **Response Time**: ≤ 2 seconds (95th percentile)
- **Timeout**: 30 seconds maximum
- **Retry Logic**: 2 retries with exponential backoff

### **Quality Targets**
- **Success Rate**: ≥ 95% successful playbook generation
- **Fallback Rate**: ≤ 5% fallback to control playbooks
- **Section Fill Rate**: ≥ 80% sections with valid search strategies

## 🔧 **Implementation Steps**

### **Step 1: Update AI Service Endpoint**
```python
@app.post("/operator/query-pack")
def query_pack():
    try:
        request_data = request.get_json()
        
        # Validate request format
        if not validate_playbook_request(request_data):
            return {"error": {"code": "VALIDATION_ERROR", "message": "Invalid request format"}}, 400
        
        # Extract user context and instructions
        user_context = request_data.get('user_context', {})
        ai_instructions = request_data.get('ai_instructions', {})
        
        # Generate playbook
        playbook = generate_playbook(user_context, ai_instructions)
        
        return playbook, 200
        
    except Exception as e:
        logger.error(f"Playbook generation failed: {str(e)}")
        return {"error": {"code": "AI_GENERATION_ERROR", "message": "Failed to generate playbook"}}, 500

def generate_playbook(user_context, ai_instructions):
    # AI logic to generate personalized sections
    # Return format matching expected response schema
    pass
```

### **Step 2: Implement Playbook Generation Logic**
```python
def generate_playbook(user_context, ai_instructions):
    page = ai_instructions.get('requirements', {}).get('page', 'home')
    max_sections = ai_instructions.get('requirements', {}).get('max_sections', 6)
    
    # Analyze user behavior
    behavioral_patterns = analyze_behavioral_patterns(user_context)
    
    # Generate sections based on page and user context
    sections = generate_sections_for_page(page, user_context, behavioral_patterns, max_sections)
    
    # Build response
    return {
        "metadata": {
            "ai_generated": True,
            "conversion_optimized": True,
            "section_count": len(sections),
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "model_version": "gpt-4-turbo",
            "prompt_version": "playbook_v3.0"
        },
        "personalized_sections": sections,
        "user_insights": extract_user_insights(user_context, behavioral_patterns)
    }
```

### **Step 3: Test Integration**
```bash
# Test AI service health
curl http://localhost:8000/health

# Test playbook generation
curl -X POST http://localhost:8000/operator/query-pack \
  -H "Content-Type: application/json" \
  -H "X-Plan-DSL-Version: 3.0" \
  -d '{
    "user_context": {
      "user_id": 123,
      "page": "home",
      "region": "ke"
    },
    "ai_instructions": {
      "task": "generate_conversion_playbook",
      "requirements": {
        "page": "home",
        "max_sections": 6,
        "conversion_optimized": true
      }
    }
  }'
```

## 📈 **Monitoring and Metrics**

### **Key Metrics to Track**
- **Playbook Generation Success Rate**: % of successful playbook generations
- **Response Time**: P95 latency for playbook generation
- **Section Quality**: % of sections with valid search strategies
- **Conversion Potential**: Distribution of high/medium/low conversion sections
- **Fallback Rate**: % of requests falling back to control playbooks

### **Logging Requirements**
```python
logger.info(f"Playbook generated: user_id={user_id}, page={page}, sections={len(sections)}, duration_ms={duration}")
logger.warning(f"Playbook generation failed: user_id={user_id}, error={error}")
logger.error(f"AI service error: {error}")
```

## 🧪 **Testing Checklist**

### **Functional Tests**
- [ ] Home page playbook generation
- [ ] PDP page playbook generation
- [ ] Wishlist page playbook generation
- [ ] Checkout page playbook generation
- [ ] Profile page playbook generation
- [ ] Error handling for invalid requests
- [ ] Fallback behavior for AI failures

### **Performance Tests**
- [ ] Response time under 2 seconds
- [ ] Success rate above 95%
- [ ] Memory usage within limits
- [ ] No memory leaks in long-running tests

### **Integration Tests**
- [ ] Rails can call AI service successfully
- [ ] Generated playbooks are valid
- [ ] Playbook execution works correctly
- [ ] Product retrieval works with AI-generated strategies

## 🚀 **Deployment Plan**

### **Phase 1: Development**
1. Implement playbook generation endpoint
2. Test with sample requests
3. Validate response format
4. Test error handling

### **Phase 2: Staging**
1. Deploy AI service updates
2. Test with Rails backend
3. Run integration tests
4. Performance testing

### **Phase 3: Production**
1. Deploy with feature flags
2. Gradual rollout (10% → 50% → 100%)
3. Monitor metrics and errors
4. Rollback plan ready

## 🆘 **Support and Troubleshooting**

### **Common Issues**
1. **Timeout Errors**: Check AI service response time
2. **Invalid Response Format**: Validate JSON schema
3. **Empty Sections**: Check search strategy generation
4. **High Fallback Rate**: Check AI service health

### **Debug Commands**
```bash
# Check AI service health
curl http://localhost:8000/health

# Test playbook generation
curl -X POST http://localhost:8000/operator/query-pack \
  -H "Content-Type: application/json" \
  -d '{"user_context":{"user_id":123,"page":"home"},"ai_instructions":{"task":"generate_conversion_playbook"}}'

# Check Rails integration
rails runner "Personalization::PlaybookGenerator.generate_for_user(123, 'home')"
```

---

**Document Version**: 3.0  
**Date**: January 15, 2025  
**Author**: Rails Backend Team  
**Target Audience**: AI Team, Python Operator Team

**🎯 KEY MESSAGE: The Rails backend is ready! Implement the playbook generation endpoint and we'll have a complete 48-hour AI-driven personalization system!**

