# Frontend Feed Integration Guide

## 🎯 Overview

The Thrifts feed system provides **AI-powered, personalized content** that adapts to each user's behavior and preferences. This guide explains how to request, receive, and render dynamic feeds.

## 🏗️ Architecture

### **Feed Types**
1. **Home Grid** (`/api/home/grid`) - Main homepage feed
2. **Dynamic Feed** (`/api/feeds/dynamic/:page`) - Page-specific feeds
3. **Legacy Feed** (`/api/feeds/start`, `/api/feeds/next`) - Traditional paginated feeds

### **Content Sources**
- **AI-Generated**: Personalized sections based on user behavior
- **Trending**: Popular products across the platform
- **Discovery**: New and diverse product recommendations
- **Fallback**: Default content when personalization fails

## 📡 **API Endpoints**

### 1. Home Grid Feed
**GET** `/api/home/grid`

**Purpose**: Main homepage with personalized content sections

**Request**:
```javascript
const response = await fetch('/api/home/grid', {
  method: 'GET',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}` // Optional for anonymous users
  }
});
```

**Response Structure**:
```json
{
  "page": "home",
  "layout": {
    "trending_strip": {
      "title": "Trending Now",
      "products": [...],
      "reason": "popular_this_week"
    },
    "discovery_grid": {
      "title": "Discover More",
      "products": [...],
      "reason": "based_on_your_taste"
    },
    "dynamic_injections": [
      {
        "slot": "top",
        "module": "your_picks_today",
        "title": "Your Picks Today",
        "products": [...],
        "reason": "personalized_for_you"
      }
    ]
  },
  "metadata": {
    "ai_generated": true,
    "user_personalized": true,
    "processing_time_ms": 245.67
  }
}
```

### 2. Dynamic Page Feed
**GET** `/api/feeds/dynamic/:page`

**Purpose**: Page-specific personalized content

**Request**:
```javascript
const response = await fetch('/api/feeds/dynamic/profile', {
  method: 'GET',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  }
});
```

**Response Structure**:
```json
{
  "page": "profile",
  "sections": [
    {
      "slot": "top",
      "module": "recommended_for_you",
      "title": "Recommended for You",
      "products": [...],
      "reason": "based_on_your_wishlist"
    }
  ],
  "user_insights": {
    "preferred_categories": ["fashion", "electronics"],
    "price_sensitivity": "medium",
    "browsing_patterns": {...}
  },
  "metadata": {
    "ai_generated": true,
    "user_personalized": true,
    "conversion_optimized": true,
    "processing_time_ms": 189.23
  }
}
```

### 3. Legacy Paginated Feed
**POST** `/api/feeds/start`
**POST** `/api/feeds/next`

**Purpose**: Traditional paginated feed system

**Start Request**:
```javascript
const response = await fetch('/api/feeds/start', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    page: 'home',
    limit: 20,
    region: 'ke',
    pickup_only: false
  })
});
```

**Next Request**:
```javascript
const response = await fetch('/api/feeds/next', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    feed_uid: 'feed_123',
    limit: 20
  })
});
```

## 🎨 **Frontend Implementation**

### **1. Feed Service**

```javascript
class FeedService {
  constructor(baseURL = '/api') {
    this.baseURL = baseURL;
  }

  // Get home grid feed
  async getHomeGrid() {
    try {
      const response = await fetch(`${this.baseURL}/home/grid`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.getToken()}`
        }
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      return this.processHomeGridData(data);
    } catch (error) {
      console.error('Failed to fetch home grid:', error);
      return this.getFallbackHomeGrid();
    }
  }

  // Get dynamic page feed
  async getDynamicFeed(page) {
    try {
      const response = await fetch(`${this.baseURL}/feeds/dynamic/${page}`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.getToken()}`
        }
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error(`Failed to fetch ${page} feed:`, error);
      return this.getFallbackFeed(page);
    }
  }

  // Process home grid data for rendering
  processHomeGridData(data) {
    return {
      trendingStrip: data.layout.trending_strip,
      discoveryGrid: data.layout.discovery_grid,
      dynamicInjections: data.layout.dynamic_injections,
      metadata: data.metadata
    };
  }

  // Fallback content when API fails
  getFallbackHomeGrid() {
    return {
      trendingStrip: {
        title: "Trending Now",
        products: [],
        reason: "fallback"
      },
      discoveryGrid: {
        title: "Discover More",
        products: [],
        reason: "fallback"
      },
      dynamicInjections: [],
      metadata: {
        ai_generated: false,
        fallback: true
      }
    };
  }

  getToken() {
    return localStorage.getItem('auth_token') || null;
  }
}
```

### **2. React Components**

#### **Home Grid Component**
```jsx
import React, { useState, useEffect } from 'react';
import { FeedService } from './services/FeedService';
import { ProductCard } from './components/ProductCard';
import { TrendingStrip } from './components/TrendingStrip';
import { DiscoveryGrid } from './components/DiscoveryGrid';

const HomeGrid = () => {
  const [feedData, setFeedData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  const feedService = new FeedService();

  useEffect(() => {
    loadHomeGrid();
  }, []);

  const loadHomeGrid = async () => {
    try {
      setLoading(true);
      const data = await feedService.getHomeGrid();
      setFeedData(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="loading">Loading personalized content...</div>;
  }

  if (error) {
    return <div className="error">Failed to load content: {error}</div>;
  }

  return (
    <div className="home-grid">
      {/* Trending Strip */}
      {feedData.trendingStrip && (
        <TrendingStrip 
          data={feedData.trendingStrip}
          reason={feedData.trendingStrip.reason}
        />
      )}

      {/* Discovery Grid */}
      {feedData.discoveryGrid && (
        <DiscoveryGrid 
          data={feedData.discoveryGrid}
          reason={feedData.discoveryGrid.reason}
        />
      )}

      {/* Dynamic Injections */}
      {feedData.dynamicInjections.map((injection, index) => (
        <DynamicSection
          key={`${injection.module}-${index}`}
          data={injection}
        />
      ))}
    </div>
  );
};

export default HomeGrid;
```

#### **Dynamic Section Component**
```jsx
import React from 'react';
import { ProductCard } from './ProductCard';

const DynamicSection = ({ data }) => {
  const { slot, module, title, products, reason } = data;

  return (
    <div className={`dynamic-section ${slot}`} data-module={module}>
      <div className="section-header">
        <h3>{title}</h3>
        <span className="reason-badge">{reason}</span>
      </div>
      
      <div className="products-grid">
        {products.map(product => (
          <ProductCard 
            key={product.id} 
            product={product}
            source="dynamic_feed"
            module={module}
          />
        ))}
      </div>
    </div>
  );
};

export default DynamicSection;
```

#### **Product Card Component**
```jsx
import React from 'react';

const ProductCard = ({ product, source, module }) => {
  const handleClick = () => {
    // Track product click
    trackProductClick(product.id, source, module);
  };

  const handleImpression = () => {
    // Track product impression
    trackProductImpression(product.id, source, module);
  };

  return (
    <div 
      className="product-card"
      onClick={handleClick}
      onViewportEnter={handleImpression}
    >
      <img 
        src={product.image_url} 
        alt={product.name}
        loading="lazy"
      />
      <div className="product-info">
        <h4>{product.name}</h4>
        <p className="price">KES {product.price}</p>
        <p className="shop">{product.shop.name}</p>
        {product.brand && <p className="brand">{product.brand}</p>}
      </div>
    </div>
  );
};

export default ProductCard;
```

### **3. Analytics Tracking**

```javascript
class AnalyticsService {
  // Track product impressions
  static trackProductImpression(productId, source, module) {
    this.trackEvent('product_impression', {
      product_id: productId,
      source: source,
      module: module,
      timestamp: new Date().toISOString()
    });
  }

  // Track product clicks
  static trackProductClick(productId, source, module) {
    this.trackEvent('product_click', {
      product_id: productId,
      source: source,
      module: module,
      timestamp: new Date().toISOString()
    });
  }

  // Track feed impressions
  static trackFeedImpression(feedData) {
    this.trackEvent('feed_impression', {
      feed_type: feedData.metadata?.ai_generated ? 'ai_generated' : 'fallback',
      sections_count: feedData.dynamicInjections?.length || 0,
      processing_time_ms: feedData.metadata?.processing_time_ms,
      timestamp: new Date().toISOString()
    });
  }

  // Generic event tracking
  static trackEvent(eventName, payload) {
    fetch('/api/events', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.getToken()}`
      },
      body: JSON.stringify({
        events: [{
          event_name: eventName,
          payload: payload,
          timestamp_utc: new Date().toISOString()
        }]
      })
    }).catch(error => {
      console.error('Analytics tracking failed:', error);
    });
  }

  static getToken() {
    return localStorage.getItem('auth_token') || null;
  }
}
```

## 🎯 **Rendering Patterns**

### **1. Home Grid Layout**
```jsx
const HomeGridLayout = ({ feedData }) => (
  <div className="home-grid-layout">
    {/* Hero Section */}
    <section className="hero-section">
      <TrendingStrip data={feedData.trendingStrip} />
    </section>

    {/* Main Content */}
    <main className="main-content">
      {/* Dynamic Sections */}
      {feedData.dynamicInjections.map((section, index) => (
        <DynamicSection 
          key={section.module}
          data={section}
          priority={index}
        />
      ))}
    </main>

    {/* Discovery Section */}
    <aside className="discovery-section">
      <DiscoveryGrid data={feedData.discoveryGrid} />
    </aside>
  </div>
);
```

### **2. Section Types**

#### **Trending Strip**
```jsx
const TrendingStrip = ({ data }) => (
  <section className="trending-strip">
    <h2>{data.title}</h2>
    <div className="products-horizontal-scroll">
      {data.products.map(product => (
        <ProductCard 
          key={product.id}
          product={product}
          variant="horizontal"
        />
      ))}
    </div>
  </section>
);
```

#### **Discovery Grid**
```jsx
const DiscoveryGrid = ({ data }) => (
  <section className="discovery-grid">
    <h2>{data.title}</h2>
    <div className="products-grid">
      {data.products.map(product => (
        <ProductCard 
          key={product.id}
          product={product}
          variant="grid"
        />
      ))}
    </div>
  </section>
);
```

### **3. Responsive Design**
```css
/* Mobile First */
.home-grid {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.trending-strip {
  overflow-x: auto;
  white-space: nowrap;
}

.products-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 1rem;
}

/* Tablet */
@media (min-width: 768px) {
  .products-grid {
    grid-template-columns: repeat(3, 1fr);
  }
}

/* Desktop */
@media (min-width: 1024px) {
  .products-grid {
    grid-template-columns: repeat(4, 1fr);
  }
  
  .home-grid {
    display: grid;
    grid-template-columns: 2fr 1fr;
    gap: 2rem;
  }
}
```

## 🔄 **State Management**

### **Redux Example**
```javascript
// feedSlice.js
import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';

export const fetchHomeGrid = createAsyncThunk(
  'feed/fetchHomeGrid',
  async (_, { rejectWithValue }) => {
    try {
      const response = await fetch('/api/home/grid');
      if (!response.ok) {
        throw new Error('Failed to fetch home grid');
      }
      return await response.json();
    } catch (error) {
      return rejectWithValue(error.message);
    }
  }
);

const feedSlice = createSlice({
  name: 'feed',
  initialState: {
    homeGrid: null,
    loading: false,
    error: null
  },
  reducers: {
    clearError: (state) => {
      state.error = null;
    }
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchHomeGrid.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchHomeGrid.fulfilled, (state, action) => {
        state.loading = false;
        state.homeGrid = action.payload;
      })
      .addCase(fetchHomeGrid.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload;
      });
  }
});

export const { clearError } = feedSlice.actions;
export default feedSlice.reducer;
```

## 🚀 **Performance Optimization**

### **1. Lazy Loading**
```jsx
import { lazy, Suspense } from 'react';

const ProductCard = lazy(() => import('./ProductCard'));
const DynamicSection = lazy(() => import('./DynamicSection'));

const HomeGrid = () => (
  <div className="home-grid">
    <Suspense fallback={<div>Loading...</div>}>
      <DynamicSection data={sectionData} />
    </Suspense>
  </div>
);
```

### **2. Virtual Scrolling**
```jsx
import { FixedSizeList as List } from 'react-window';

const VirtualizedProductGrid = ({ products }) => (
  <List
    height={600}
    itemCount={products.length}
    itemSize={200}
    itemData={products}
  >
    {({ index, style, data }) => (
      <div style={style}>
        <ProductCard product={data[index]} />
      </div>
    )}
  </List>
);
```

### **3. Image Optimization**
```jsx
const ProductCard = ({ product }) => (
  <div className="product-card">
    <img
      src={product.image_url}
      alt={product.name}
      loading="lazy"
      decoding="async"
      sizes="(max-width: 768px) 50vw, (max-width: 1024px) 33vw, 25vw"
      srcSet={`
        ${product.image_url}?w=200 200w,
        ${product.image_url}?w=400 400w,
        ${product.image_url}?w=600 600w
      `}
    />
  </div>
);
```

## 🧪 **Testing**

### **Unit Tests**
```javascript
// FeedService.test.js
import { FeedService } from './FeedService';

describe('FeedService', () => {
  let feedService;

  beforeEach(() => {
    feedService = new FeedService();
  });

  test('should fetch home grid successfully', async () => {
    const mockResponse = {
      page: 'home',
      layout: {
        trending_strip: { title: 'Trending', products: [] },
        discovery_grid: { title: 'Discover', products: [] },
        dynamic_injections: []
      }
    };

    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve(mockResponse)
    });

    const result = await feedService.getHomeGrid();
    expect(result.trendingStrip).toBeDefined();
    expect(result.discoveryGrid).toBeDefined();
  });

  test('should handle API errors gracefully', async () => {
    global.fetch = jest.fn().mockRejectedValue(new Error('Network error'));

    const result = await feedService.getHomeGrid();
    expect(result.metadata.fallback).toBe(true);
  });
});
```

## 📱 **Mobile Considerations**

### **Touch Interactions**
```jsx
const ProductCard = ({ product }) => {
  const [isPressed, setIsPressed] = useState(false);

  return (
    <div
      className={`product-card ${isPressed ? 'pressed' : ''}`}
      onTouchStart={() => setIsPressed(true)}
      onTouchEnd={() => setIsPressed(false)}
      onClick={handleClick}
    >
      {/* Product content */}
    </div>
  );
};
```

### **Pull to Refresh**
```jsx
import { usePullToRefresh } from 'react-pull-to-refresh';

const HomeGrid = () => {
  const { isRefreshing, onRefresh } = usePullToRefresh({
    onRefresh: async () => {
      await loadHomeGrid();
    }
  });

  return (
    <div className="home-grid">
      {isRefreshing && <div className="refresh-indicator">Refreshing...</div>}
      {/* Feed content */}
    </div>
  );
};
```

## 🎯 **Best Practices**

1. **Always handle errors gracefully** - Show fallback content when API fails
2. **Track user interactions** - Send analytics events for optimization
3. **Optimize for performance** - Use lazy loading and virtual scrolling
4. **Test different scenarios** - Cold start users, network failures, etc.
5. **Provide loading states** - Show skeleton screens while loading
6. **Handle offline scenarios** - Cache content for offline viewing
7. **Monitor performance** - Track loading times and user engagement

This guide provides everything needed to integrate with the Thrifts feed system! 🚀
