# AI Team Response Requirements for Conversion-Optimized Personalization

## 🎯 **OVERVIEW**

This document specifies how the AI team should analyze user snapshots and create **conversion-optimized, personalized sections** that can be deployed across any page for maximum conversion. The AI's job is to understand user behavior and provide **reusable search strategies** - NOT page-specific personalization or product counts.

---

## 🧠 **AI'S ROLE: CONVERSION-FOCUSED PERSONALIZATION**

### **What the AI Does:**
1. **Analyzes User Snapshot**: Understands user's interests, behavior, and conversion triggers
2. **Creates Reusable Sections**: Generates personalized sections that work across all pages
3. **Provides Search Strategies**: Gives Rails keywords and filters for product retrieval
4. **Identifies Conversion Potential**: Rates sections by their conversion likelihood

### **What Rails Does:**
1. **Executes Searches**: Uses AI's keywords to find products
2. **Optimizes Placement**: Decides where to show sections for maximum conversion
3. **Handles Pagination**: Continuously feeds products as user scrolls
4. **Manages Performance**: Optimizes queries and caching

---

## 📄 **PAGE CONTEXTS FOR AI UNDERSTANDING**

### **Home Page**
- **Purpose**: First impression, discovery, engagement
- **Conversion Goals**: Browse → View, View → Add to Cart
- **User Intent**: Exploring, browsing, discovering new products
- **Section Strategy**: High-conversion trending at top, discovery at bottom
- **Key Metrics**: Engagement, time on page, scroll depth

### **Product Detail Page (PDP)**
- **Purpose**: Product information, purchase decision, related products
- **Conversion Goals**: View → Add to Cart, Add to Cart → Purchase
- **User Intent**: Evaluating specific product, comparing options
- **Section Strategy**: Similar products (based on current product), complementary items, completion
- **Key Metrics**: Add to cart rate, purchase conversion, related product clicks
- **Note**: Similar sections must reference the current product being viewed

### **Wishlist Page**
- **Purpose**: Saved items, re-engagement, purchase reminders
- **Conversion Goals**: Wishlist → Add to Cart, Wishlist → Purchase
- **User Intent**: Returning to saved items, ready to buy
- **Section Strategy**: Trending items, price drops, similar products
- **Key Metrics**: Wishlist to cart conversion, purchase rate

### **Checkout Page**
- **Purpose**: Final purchase decision, upsell opportunities
- **Conversion Goals**: Cart → Purchase, Upsell → Additional Purchase
- **User Intent**: Completing purchase, considering add-ons
- **Section Strategy**: Complementary products, completion items, upsells
- **Key Metrics**: Checkout completion, upsell conversion, cart abandonment

### **Search Results Page**
- **Purpose**: Finding specific products, search refinement
- **Conversion Goals**: Search → View, View → Add to Cart
- **User Intent**: Looking for specific items, refining search
- **Section Strategy**: Search completion, similar products, trending in category
- **Key Metrics**: Search to view rate, search to cart conversion


---

## 📡 **API CONTRACT**

### **Endpoint**
```
POST http://localhost:8000/operator/query-pack
```

### **Request Format (What Rails Sends)**

**Note**: AI has no database access, so only product metadata is included (no IDs)
```json
{
  "user_context": {
    "user_id": 123,
    "session_id": "sess_abc123",
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
    "meso_events": [...],
    "macro_events": [...]
  },
  "ai_instructions": {
    "task": "generate_conversion_sections",
    "requirements": {
      "reusable_sections": true,
      "conversion_optimized": true,
      "personalized_titles": true,
      "search_strategies": true,
      "max_sections": 6,
      "conversion_rating": true
    }
  }
}
```

---

## 📤 **REQUIRED RESPONSE FORMAT**

### **Response Structure**
```json
{
  "personalized_sections": [
    {
      "id": "trending_nike_sneakers",
      "title": "Trending Nike Sneakers You'll Love",
      "type": "trending",
      "conversion_potential": "high",
      "placement_suggestions": ["home_top", "pdp_below", "wishlist_engagement"],
      "search_strategy": {
        "keywords": ["nike sneakers", "white athletic shoes"],
        "filters": {
          "brand": "Nike",
          "category": "sneakers",
          "color": "white",
          "style": "athletic"
        },
        "algorithm": "trending",
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
        "keywords": ["white nike air max", "similar white sneakers"],
        "filters": {
          "reference_product": "White Nike Air Max",
          "color": "white",
          "style": "athletic",
          "price_range": [100, 200]
        },
        "algorithm": "similarity"
      }
    },
    {
      "id": "complete_sneaker_look",
      "title": "Complete Your Sneaker Look",
      "type": "complementary",
      "conversion_potential": "high",
      "placement_suggestions": ["pdp_completion", "checkout_upsell", "home_bottom"],
      "search_strategy": {
        "keywords": ["athletic wear", "sneaker accessories", "sports clothing"],
        "filters": {
          "reference_product": "White Nike Air Max",
          "category": "athletic wear",
          "style": "athletic"
        },
        "algorithm": "complementary"
      }
    },
    {
      "id": "discovery_grid",
      "title": "Discover New Styles",
      "type": "discovery",
      "conversion_potential": "high",
      "placement_suggestions": ["home_top", "home_middle", "wishlist_engagement"],
      "search_strategy": {
        "keywords": ["fashion trends", "new arrivals", "style inspiration"],
        "filters": {
          "excluded_products": ["White Nike Air Max"],
          "diversity_boost": true
        },
        "algorithm": "diversity"
      }
    }
  ],
  "user_insights": {
    "primary_interests": ["nike", "sneakers", "white color", "athletic style"],
    "behavioral_patterns": ["price_explorer", "brand_loyal"],
    "conversion_triggers": ["trending_items", "similar_products", "completion"],
    "intent": "browsing_sneakers"
  },
  "metadata": {
    "ai_generated": true,
    "timestamp": "2025-01-15T10:25:00Z",
    "section_count": 4,
    "conversion_optimized": true
  }
}
```

---

## 🔧 **SECTION SPECIFICATION**

### **Required Fields**
- **`id`** (string): Unique section identifier
- **`title`** (string): **HIGHLY PERSONALIZED** section title
- **`type`** (string): Section type from allowed list
- **`conversion_potential`** (string): "high", "medium", "low" - likelihood to convert
- **`placement_suggestions`** (array): Suggested page placements for maximum conversion
- **`search_strategy`** (object): **Keywords and filters for Rails to execute**

### **Search Strategy Structure**
```json
{
  "keywords": ["specific search terms"],
  "filters": {
    "category": "sneakers",
    "brand": "Nike",
    "color": "white",
    "style": "athletic",
    "price_range": [100, 200],
    "reference_product": "White Nike Air Max"
  },
  "algorithm": "trending|similarity|complementary|diversity|completion",
  "time_window": "7d|30d|90d"
}
```

### **Allowed Section Types**
- **`trending`**: Popular products in user's specific interest area
- **`similar`**: Products similar to user's recent views
- **`complementary`**: Products that complete user's look/needs
- **`discovery`**: Diverse products to expand user's interests (HIGH CONVERSION POTENTIAL)
- **`completion`**: Products that complete user's search intent

### **Conversion Potential Levels**
- **`high`**: Sections most likely to drive immediate conversions (trending, complementary, discovery)
- **`medium`**: Sections that support conversion journey (similar, completion)
- **`low`**: Sections for engagement and exploration (exploration, diversity)

### **Placement Suggestions**
- **`home_top`**: High-conversion trending sections at top of home page
- **`home_middle`**: Medium-conversion sections in middle of home page
- **`home_bottom`**: Discovery sections at bottom of home page
- **`pdp_below`**: Below product details for related products
- **`pdp_completion`**: Complete the look section on PDP
- **`pdp_upsell`**: Upsell opportunities on PDP
- **`checkout_upsell`**: Upsell opportunities during checkout
- **`checkout_related`**: Related products during checkout
- **`wishlist_engagement`**: Re-engagement sections on wishlist
- **`wishlist_exploration`**: Discovery sections on wishlist
- **`search_completion`**: Search completion suggestions
- **`search_related`**: Related products on search results

---

## 🧠 **AI DECISION LOGIC: CONVERSION-OPTIMIZED PERSONALIZATION**

### **1. Snapshot Analysis**
```python
# Analyze user's interests from snapshot
user_interests = extract_interests(micro_events, meso_events, macro_events)
# Example: ["nike", "sneakers", "white color", "athletic style"]

behavioral_patterns = analyze_behavior(behavioral_patterns)
# Example: ["price_explorer", "brand_loyal", "category_hopper"]

conversion_triggers = identify_conversion_triggers(user_interests, behavioral_patterns)
# Example: ["trending_items", "similar_products", "completion", "price_sensitivity"]

# Consider page contexts for optimal placement
page_contexts = {
  "home": {"goal": "engagement", "metrics": ["scroll_depth", "time_on_page"]},
  "pdp": {"goal": "conversion", "metrics": ["add_to_cart", "purchase"]},
  "checkout": {"goal": "completion", "metrics": ["checkout_completion", "upsell"]},
  "wishlist": {"goal": "re_engagement", "metrics": ["wishlist_to_cart", "purchase"]},
  "search": {"goal": "search_completion", "metrics": ["search_to_view", "search_to_cart"]},
}
```

### **2. Section Generation Rules**

#### **Title Personalization (CRITICAL)**
- ❌ **WRONG**: "Trending Picks For You"
- ✅ **RIGHT**: "Trending Nike Sneakers You'll Love"
- ❌ **WRONG**: "Complete Your Look"
- ✅ **RIGHT**: "Complete Your Sneaker Look"
- ❌ **WRONG**: "Discover New Styles"
- ✅ **RIGHT**: "More White Sneakers Like This"

#### **Conversion Potential Assessment**
- **High**: Trending items, complementary products, discovery items, price-sensitive items
- **Medium**: Similar products, completion items, brand-loyal items
- **Low**: Exploration items, diverse categories, general browsing

#### **Placement Strategy by Page Context**
- **Home Page**: High-conversion trending and discovery sections throughout
- **PDP**: Similar products, complementary items, completion sections
- **Checkout**: Upsell opportunities, complementary products
- **Wishlist**: Re-engagement trending, price drops, similar products
- **Search Results**: Search completion, related products, trending in category

#### **Page Context Integration**
- **Understand Page Purpose**: Each page has specific conversion goals
- **Match Section to Context**: Trending sections work on home, similar on PDP
- **PDP Similar Logic**: Similar sections on PDP must reference the current product being viewed
- **Consider User Journey**: Home → PDP → Checkout flow optimization
- **Optimize for Page Metrics**: Engagement on home, conversion on checkout

#### **Search Strategy Personalization**
- **Use Specific Keywords**: Extract from user's actual interests
- **Apply Contextual Filters**: Use product metadata from their views
- **Consider Behavioral Patterns**: Price exploration, brand loyalty, etc.

### **3. Conversion-Optimized Examples**

#### **Sneaker Enthusiast (User viewed White Nike Air Max)**
```json
{
  "personalized_sections": [
    {
      "id": "trending_nike_sneakers",
      "title": "Trending Nike Sneakers You'll Love",
      "type": "trending",
      "conversion_potential": "high",
      "placement_suggestions": ["home_top", "pdp_below", "wishlist_engagement"],
      "search_strategy": {
        "keywords": ["nike sneakers", "white athletic shoes"],
        "filters": {
          "brand": "Nike",
          "category": "sneakers",
          "color": "white"
        }
      }
    },
    {
      "id": "more_white_sneakers",
      "title": "More White Sneakers Like This",
      "type": "similar",
      "conversion_potential": "medium",
      "placement_suggestions": ["pdp_similar", "home_middle", "checkout_related"],
      "search_strategy": {
        "keywords": ["white nike air max", "similar white sneakers"],
        "filters": {
          "reference_product": "White Nike Air Max",
          "color": "white",
          "style": "athletic"
        }
      }
    }
  ],
  "user_insights": {
    "primary_interests": ["nike", "sneakers", "white color", "athletic style"],
    "behavioral_patterns": ["price_explorer", "brand_loyal"],
    "conversion_triggers": ["trending_items", "similar_products", "brand_loyalty"]
  }
}
```

#### **Fashion Explorer (User viewed dresses, bags, shoes)**
```json
{
  "personalized_sections": [
    {
      "id": "trending_fashion_mix",
      "title": "Trending Fashion Mix You'll Love",
      "type": "trending",
      "conversion_potential": "high",
      "placement_suggestions": ["home_top", "pdp_below", "wishlist_engagement"],
      "search_strategy": {
        "keywords": ["fashion trends", "style mix", "outfit inspiration"],
        "filters": {
          "preferred_categories": ["dresses", "bags", "shoes"],
          "price_range": [50, 300]
        }
      }
    },
    {
      "id": "discover_new_categories",
      "title": "Discover New Categories",
      "type": "discovery",
      "conversion_potential": "high",
      "placement_suggestions": ["home_top", "home_middle", "wishlist_engagement"],
      "search_strategy": {
        "keywords": ["new fashion categories", "style exploration"],
        "filters": {
          "excluded_categories": ["dresses", "bags", "shoes"],
          "diversity_boost": true
        }
      }
    }
  ],
  "user_insights": {
    "primary_interests": ["fashion", "dresses", "bags", "shoes"],
    "behavioral_patterns": ["category_hopper", "style_explorer"],
    "conversion_triggers": ["trending_items", "category_diversity", "style_mix"]
  }
}
```

---

## 🎯 **KEY PRINCIPLES**

### **1. Conversion-Optimized Personalization**
- **Extract User Interests**: From product metadata in events
- **Create Specific Titles**: Use user's actual interests in titles
- **Assess Conversion Potential**: Rate sections by likelihood to convert
- **Prioritize Discovery**: Discovery sections are equally important for conversion
- **Suggest Optimal Placement**: Recommend where sections will convert best

### **2. Reusable Sections Across Pages**
- **AI Generates Sections**: Personalized sections that work anywhere
- **Rails Optimizes Placement**: Decides where to show sections for maximum conversion
- **No Page-Specific Logic**: AI focuses on personalization, Rails focuses on conversion
- **Cross-Page Deployment**: Same sections can appear on home, PDP, checkout, wishlist

### **3. No Product Counts**
- **AI Provides Strategy**: Keywords, filters, algorithms, conversion potential
- **Rails Handles Execution**: Product retrieval, pagination, infinite scroll
- **Continuous Discovery**: User can scroll indefinitely through relevant content

### **4. Behavioral Integration**
- **Use Patterns**: Price exploration, brand loyalty, category hopping
- **Apply Intent**: Search vs browse vs shop behavior
- **Consider Context**: Recent views, search history, engagement velocity
- **Identify Triggers**: What drives this user to convert

---

## ⚠️ **COMMON MISTAKES TO AVOID**

### **❌ Generic Personalization**
```json
{
  "title": "Trending Picks For You",
  "conversion_potential": "medium",
  "placement_suggestions": ["home_top"],
  "search_strategy": {
    "keywords": ["trending products"],
    "filters": {}
  }
}
```

### **✅ Conversion-Optimized Personalization**
```json
{
  "title": "Trending Nike Sneakers You'll Love",
  "conversion_potential": "high",
  "placement_suggestions": ["home_top", "pdp_below", "wishlist_engagement"],
  "search_strategy": {
    "keywords": ["nike sneakers", "white athletic shoes"],
        "filters": {
          "brand": "Nike",
          "category": "sneakers",
          "color": "white"
        }
  }
}
```

### **❌ Page-Specific Logic**
```json
{
  "sections": [
    {
      "id": "home_trending",
      "title": "Home Page Trending",
      "page_specific": "home"
    }
  ]
}
```

### **✅ Reusable Sections**
```json
{
  "personalized_sections": [
    {
      "id": "trending_nike_sneakers",
      "title": "Trending Nike Sneakers You'll Love",
      "conversion_potential": "high",
      "placement_suggestions": ["home_top", "pdp_below", "wishlist_engagement"]
    }
  ]
}
```

---

## 🚀 **IMPLEMENTATION CHECKLIST**

### **For Each Section:**
- [ ] **Title is specific** to user's interests (not generic)
- [ ] **Conversion potential** is assessed (high/medium/low)
- [ ] **Placement suggestions** are provided for optimal conversion
- [ ] **Keywords are relevant** to user's behavior
- [ ] **Filters use** user's actual product metadata
- [ ] **Algorithm matches** the section type and user intent
- [ ] **No product limits** specified (Rails handles pagination)

### **For Overall Response:**
- [ ] **Sections are reusable** across different pages
- [ ] **Conversion potential** varies across sections
- [ ] **User insights** include conversion triggers
- [ ] **Response time** under 2 seconds
- [ ] **No page-specific logic** in AI response

---

## 📝 **CHANGELOG**

### **Version 3.0 (Current)**
- ✅ Conversion-optimized personalization
- ✅ Reusable sections across pages
- ✅ Conversion potential assessment
- ✅ Placement suggestions for maximum conversion
- ✅ No page-specific logic in AI
- ✅ Rails handles conversion optimization

### **Version 2.0 (Previous)**
- ✅ True personalization with specific titles
- ✅ Keyword-based search strategies
- ✅ Behavioral pattern integration
- ❌ Page-specific personalization

### **Version 1.0 (Legacy)**
- ❌ Generic titles
- ❌ Fixed product limits
- ❌ Basic personalization