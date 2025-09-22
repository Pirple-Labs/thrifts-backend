# 🎯 Frontend Dynamic Product Delivery Guide

## 📋 **Overview**

This guide explains how the frontend receives and displays dynamic, personalized product recommendations from the Rails backend's playbook system. The system delivers different product sections for different users based on AI-generated playbooks.

---

## 🏗️ **Backend → Frontend Data Flow**

### **1. API Endpoints Structure**

The backend provides page-specific endpoints that return personalized layouts:

```typescript
// API Endpoints
GET /api/home/grid                    // Home page layout
GET /api/pdp/layout?sku=SKU_123       // Product detail page layout  
GET /api/wishlist/layout              // Wishlist page layout
GET /api/feeds/dynamic/:page          // Generic dynamic feed
```

### **2. Backend Response Format**

Each endpoint returns a structured response with modules containing products:

```typescript
interface PlaybookResponse {
  page: string;
  playbook_id: string;
  modules: Module[];
  metadata: {
    ai_generated: boolean;
    generated_at: string;
    expires_at: string;
    execution_time_ms: number;
  };
}

interface Module {
  id: string;                    // e.g., "trending_nike_sneakers"
  type: string;                  // "trending" | "similar" | "complementary" | "diversity"
  placement: string;             // "home_top" | "pdp_below" | "wishlist_engagement"
  items: Product[];
  metadata: {
    title: string;               // "Trending Nike Sneakers You'll Love"
    conversion_potential: string; // "high" | "medium" | "low"
    reason: string;              // Why this section was shown
  };
}

interface Product {
  id: number;
  name: string;
  price: number;
  main_image: string;
  supplementary_images: string[];
  description: string;
  shop_name: string;
  sku: string;
  // Additional product fields...
}
```

---

## 🎨 **Frontend Implementation**

### **1. API Service Layer**

```typescript
// services/playbookApi.ts
class PlaybookApiService {
  private baseUrl = '/api';

  async getHomeLayout(params: {
    region?: string;
    pickup_only?: boolean;
    geohash6?: string;
  }): Promise<PlaybookResponse> {
    const queryParams = new URLSearchParams();
    if (params.region) queryParams.set('region', params.region);
    if (params.pickup_only) queryParams.set('pickup_only', 'true');
    if (params.geohash6) queryParams.set('geohash6', params.geohash6);

    const response = await fetch(`${this.baseUrl}/home/grid?${queryParams}`);
    return response.json();
  }

  async getPdpLayout(sku: string): Promise<PlaybookResponse> {
    const response = await fetch(`${this.baseUrl}/pdp/layout?sku=${sku}`);
    return response.json();
  }

  async getWishlistLayout(): Promise<PlaybookResponse> {
    const response = await fetch(`${this.baseUrl}/wishlist/layout`);
    return response.json();
  }
}
```

### **2. React Component Structure**

```typescript
// components/PersonalizedLayout.tsx
interface PersonalizedLayoutProps {
  page: 'home' | 'pdp' | 'wishlist';
  additionalParams?: Record<string, any>;
}

export const PersonalizedLayout: React.FC<PersonalizedLayoutProps> = ({
  page,
  additionalParams = {}
}) => {
  const [playbookData, setPlaybookData] = useState<PlaybookResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadPlaybookData();
  }, [page, additionalParams]);

  const loadPlaybookData = async () => {
    try {
      setLoading(true);
      setError(null);
      
      let data: PlaybookResponse;
      switch (page) {
        case 'home':
          data = await playbookApi.getHomeLayout(additionalParams);
          break;
        case 'pdp':
          data = await playbookApi.getPdpLayout(additionalParams.sku);
          break;
        case 'wishlist':
          data = await playbookApi.getWishlistLayout();
          break;
        default:
          throw new Error(`Unsupported page: ${page}`);
      }
      
      setPlaybookData(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <LayoutSkeleton />;
  if (error) return <ErrorFallback error={error} onRetry={loadPlaybookData} />;
  if (!playbookData) return <EmptyState />;

  return (
    <div className="personalized-layout">
      {playbookData.modules.map((module) => (
        <ProductSection
          key={module.id}
          module={module}
          placement={module.placement}
        />
      ))}
    </div>
  );
};
```

### **3. Dynamic Product Section Component**

```typescript
// components/ProductSection.tsx
interface ProductSectionProps {
  module: Module;
  placement: string;
}

export const ProductSection: React.FC<ProductSectionProps> = ({
  module,
  placement
}) => {
  const sectionConfig = getSectionConfig(module.type, placement);
  
  return (
    <div 
      className={`product-section ${sectionConfig.containerClass}`}
      data-module-id={module.id}
      data-placement={placement}
    >
      <SectionHeader
        title={module.metadata.title}
        conversionPotential={module.metadata.conversion_potential}
        reason={module.metadata.reason}
      />
      
      <ProductGrid
        products={module.items}
        layout={sectionConfig.layout}
        maxItems={sectionConfig.maxItems}
      />
    </div>
  );
};

// Section configuration based on type and placement
const getSectionConfig = (type: string, placement: string) => {
  const configs = {
    'trending': {
      'home_top': { layout: 'horizontal-scroll', maxItems: 8, containerClass: 'trending-strip' },
      'pdp_below': { layout: 'grid-2x2', maxItems: 4, containerClass: 'trending-grid' },
      'wishlist_engagement': { layout: 'horizontal-scroll', maxItems: 6, containerClass: 'trending-mini' }
    },
    'similar': {
      'pdp_below_details': { layout: 'grid-2x3', maxItems: 6, containerClass: 'similar-grid' },
      'home_middle': { layout: 'horizontal-scroll', maxItems: 8, containerClass: 'similar-strip' }
    },
    'complementary': {
      'pdp_completion': { layout: 'grid-1x4', maxItems: 4, containerClass: 'complementary-strip' },
      'checkout_upsell': { layout: 'horizontal-scroll', maxItems: 6, containerClass: 'upsell-strip' }
    },
    'diversity': {
      'home_top': { layout: 'grid-3x2', maxItems: 6, containerClass: 'discovery-grid' },
      'home_middle': { layout: 'grid-2x3', maxItems: 6, containerClass: 'diversity-grid' }
    }
  };
  
  return configs[type]?.[placement] || { layout: 'grid-2x2', maxItems: 4, containerClass: 'default-grid' };
};
```

### **4. Product Grid Component**

```typescript
// components/ProductGrid.tsx
interface ProductGridProps {
  products: Product[];
  layout: 'horizontal-scroll' | 'grid-2x2' | 'grid-2x3' | 'grid-3x2' | 'grid-1x4';
  maxItems: number;
}

export const ProductGrid: React.FC<ProductGridProps> = ({
  products,
  layout,
  maxItems
}) => {
  const displayProducts = products.slice(0, maxItems);
  
  const gridClass = `product-grid product-grid--${layout}`;
  
  return (
    <div className={gridClass}>
      {displayProducts.map((product) => (
        <ProductCard
          key={product.id}
          product={product}
          layout={layout}
        />
      ))}
    </div>
  );
};
```

---

## 🎯 **Page-Specific Implementations**

### **1. Home Page**

```typescript
// pages/HomePage.tsx
export const HomePage: React.FC = () => {
  const [userLocation, setUserLocation] = useState<Geolocation | null>(null);
  
  const additionalParams = {
    region: 'ke',
    pickup_only: false,
    geohash6: userLocation?.geohash6
  };

  return (
    <div className="home-page">
      <HeroSection />
      
      <PersonalizedLayout
        page="home"
        additionalParams={additionalParams}
      />
      
      <Footer />
    </div>
  );
};
```

**Expected Home Page Modules:**
- `trending_nike_sneakers` (placement: `home_top`)
- `discovery_grid` (placement: `home_middle`) 
- `more_white_sneakers` (placement: `home_middle`)
- `complete_sneakers` (placement: `home_bottom`)

### **2. Product Detail Page (PDP)**

```typescript
// pages/ProductDetailPage.tsx
interface ProductDetailPageProps {
  sku: string;
}

export const ProductDetailPage: React.FC<ProductDetailPageProps> = ({ sku }) => {
  return (
    <div className="product-detail-page">
      <ProductInfo sku={sku} />
      
      <PersonalizedLayout
        page="pdp"
        additionalParams={{ sku }}
      />
    </div>
  );
};
```

**Expected PDP Modules:**
- `similar_items` (placement: `pdp_below_details`)
- `complementary_items` (placement: `pdp_completion`)
- `trending_related` (placement: `pdp_below`)

### **3. Wishlist Page**

```typescript
// pages/WishlistPage.tsx
export const WishlistPage: React.FC = () => {
  return (
    <div className="wishlist-page">
      <WishlistHeader />
      
      <PersonalizedLayout
        page="wishlist"
      />
    </div>
  );
};
```

**Expected Wishlist Modules:**
- `price_drops` (placement: `wishlist_top`)
- `similar_saved` (placement: `wishlist_engagement`)
- `trending_saved` (placement: `wishlist_bottom`)

---

## 🔄 **State Management**

### **1. Redux Store Structure**

```typescript
// store/playbookSlice.ts
interface PlaybookState {
  [page: string]: {
    data: PlaybookResponse | null;
    loading: boolean;
    error: string | null;
    lastFetched: number | null;
    expiresAt: number | null;
  };
}

const playbookSlice = createSlice({
  name: 'playbook',
  initialState: {} as PlaybookState,
  reducers: {
    setLoading: (state, action) => {
      const { page } = action.payload;
      if (!state[page]) state[page] = { data: null, loading: false, error: null, lastFetched: null, expiresAt: null };
      state[page].loading = true;
      state[page].error = null;
    },
    setData: (state, action) => {
      const { page, data } = action.payload;
      state[page] = {
        data,
        loading: false,
        error: null,
        lastFetched: Date.now(),
        expiresAt: new Date(data.metadata.expires_at).getTime()
      };
    },
    setError: (state, action) => {
      const { page, error } = action.payload;
      state[page].loading = false;
      state[page].error = error;
    }
  }
});
```

### **2. Caching Strategy**

```typescript
// hooks/usePlaybookData.ts
export const usePlaybookData = (page: string, params: Record<string, any> = {}) => {
  const dispatch = useDispatch();
  const playbookState = useSelector((state: RootState) => state.playbook[page]);
  
  const fetchData = useCallback(async () => {
    // Check if data is still valid
    if (playbookState?.data && playbookState.expiresAt && Date.now() < playbookState.expiresAt) {
      return; // Data is still fresh
    }
    
    dispatch(setLoading({ page }));
    
    try {
      let data: PlaybookResponse;
      switch (page) {
        case 'home':
          data = await playbookApi.getHomeLayout(params);
          break;
        case 'pdp':
          data = await playbookApi.getPdpLayout(params.sku);
          break;
        case 'wishlist':
          data = await playbookApi.getWishlistLayout();
          break;
        default:
          throw new Error(`Unsupported page: ${page}`);
      }
      
      dispatch(setData({ page, data }));
    } catch (error) {
      dispatch(setError({ page, error: error.message }));
    }
  }, [page, params, dispatch, playbookState]);
  
  useEffect(() => {
    fetchData();
  }, [fetchData]);
  
  return {
    data: playbookState?.data,
    loading: playbookState?.loading || false,
    error: playbookState?.error,
    refetch: fetchData
  };
};
```

---

## 🎨 **Styling & Layout**

### **1. CSS Grid Classes**

```css
/* Product Grid Layouts */
.product-grid--horizontal-scroll {
  display: flex;
  overflow-x: auto;
  gap: 1rem;
  padding: 1rem 0;
}

.product-grid--grid-2x2 {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 1rem;
}

.product-grid--grid-2x3 {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  grid-template-rows: repeat(3, 1fr);
  gap: 1rem;
}

.product-grid--grid-3x2 {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  grid-template-rows: repeat(2, 1fr);
  gap: 1rem;
}

.product-grid--grid-1x4 {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 1rem;
}

/* Section Containers */
.trending-strip {
  margin: 2rem 0;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 12px;
  padding: 1.5rem;
}

.discovery-grid {
  margin: 2rem 0;
  background: #f8f9fa;
  border-radius: 12px;
  padding: 1.5rem;
}

.similar-grid {
  margin: 1.5rem 0;
  border-top: 1px solid #e9ecef;
  padding-top: 1.5rem;
}
```

### **2. Responsive Design**

```css
/* Mobile-first responsive design */
@media (max-width: 768px) {
  .product-grid--grid-3x2 {
    grid-template-columns: repeat(2, 1fr);
    grid-template-rows: repeat(3, 1fr);
  }
  
  .product-grid--grid-1x4 {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .trending-strip {
    margin: 1rem 0;
    padding: 1rem;
  }
}

@media (max-width: 480px) {
  .product-grid--grid-2x2,
  .product-grid--grid-2x3,
  .product-grid--grid-3x2 {
    grid-template-columns: 1fr;
  }
}
```

---

## ⚡ **Performance Optimizations**

### **1. Lazy Loading**

```typescript
// components/LazyProductSection.tsx
export const LazyProductSection = React.lazy(() => import('./ProductSection'));

// Usage with Suspense
<Suspense fallback={<SectionSkeleton />}>
  <LazyProductSection module={module} placement={module.placement} />
</Suspense>
```

### **2. Image Optimization**

```typescript
// components/OptimizedProductImage.tsx
export const OptimizedProductImage: React.FC<{ src: string; alt: string }> = ({ src, alt }) => {
  return (
    <img
      src={src}
      alt={alt}
      loading="lazy"
      decoding="async"
      style={{
        width: '100%',
        height: 'auto',
        objectFit: 'cover'
      }}
    />
  );
};
```

### **3. Memoization**

```typescript
// Memoized product card to prevent unnecessary re-renders
export const ProductCard = React.memo<ProductCardProps>(({ product, layout }) => {
  return (
    <div className={`product-card product-card--${layout}`}>
      <OptimizedProductImage src={product.main_image} alt={product.name} />
      <h3>{product.name}</h3>
      <p className="price">${product.price}</p>
      <p className="shop">{product.shop_name}</p>
    </div>
  );
});
```

---

## 🚨 **Error Handling & Fallbacks**

### **1. Error Boundaries**

```typescript
// components/PlaybookErrorBoundary.tsx
export class PlaybookErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('Playbook Error:', error, errorInfo);
    // Log to error tracking service
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="error-fallback">
          <h3>Something went wrong loading personalized content</h3>
          <button onClick={() => this.setState({ hasError: false, error: null })}>
            Try Again
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
```

### **2. Fallback Content**

```typescript
// components/FallbackContent.tsx
export const FallbackContent: React.FC<{ page: string }> = ({ page }) => {
  const fallbackSections = {
    home: [
      { id: 'trending_fallback', title: 'Trending Now', type: 'trending' },
      { id: 'featured_fallback', title: 'Featured Products', type: 'featured' }
    ],
    pdp: [
      { id: 'similar_fallback', title: 'Similar Items', type: 'similar' }
    ],
    wishlist: [
      { id: 'saved_fallback', title: 'Your Saved Items', type: 'saved' }
    ]
  };

  return (
    <div className="fallback-content">
      {fallbackSections[page]?.map(section => (
        <StaticProductSection key={section.id} section={section} />
      ))}
    </div>
  );
};
```

---

## 📊 **Analytics & Tracking**

### **1. Section Visibility Tracking**

```typescript
// hooks/useSectionAnalytics.ts
export const useSectionAnalytics = (moduleId: string, placement: string) => {
  const [isVisible, setIsVisible] = useState(false);
  const [hasTracked, setHasTracked] = useState(false);

  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !hasTracked) {
          setIsVisible(true);
          setHasTracked(true);
          
          // Track section view
          analytics.track('section_viewed', {
            module_id: moduleId,
            placement: placement,
            timestamp: Date.now()
          });
        }
      },
      { threshold: 0.5 }
    );

    if (ref.current) {
      observer.observe(ref.current);
    }

    return () => observer.disconnect();
  }, [moduleId, placement, hasTracked]);

  return ref;
};
```

### **2. Product Interaction Tracking**

```typescript
// components/TrackedProductCard.tsx
export const TrackedProductCard: React.FC<ProductCardProps> = ({ product, layout }) => {
  const handleClick = () => {
    analytics.track('product_clicked', {
      product_id: product.id,
      product_name: product.name,
      price: product.price,
      layout: layout,
      timestamp: Date.now()
    });
  };

  return (
    <div className="product-card" onClick={handleClick}>
      {/* Product card content */}
    </div>
  );
};
```

---

## 🔧 **Development & Testing**

### **1. Mock Data for Development**

```typescript
// mocks/playbookMocks.ts
export const mockHomePlaybook: PlaybookResponse = {
  page: 'home',
  playbook_id: 'pb_mock_home_123',
  modules: [
    {
      id: 'trending_nike_sneakers',
      type: 'trending',
      placement: 'home_top',
      items: mockProducts.slice(0, 8),
      metadata: {
        title: 'Trending Nike Sneakers You\'ll Love',
        conversion_potential: 'high',
        reason: 'user_interest_nike'
      }
    },
    {
      id: 'discovery_grid',
      type: 'diversity',
      placement: 'home_middle',
      items: mockProducts.slice(8, 14),
      metadata: {
        title: 'Discover New Styles',
        conversion_potential: 'high',
        reason: 'diversity_boost'
      }
    }
  ],
  metadata: {
    ai_generated: true,
    generated_at: new Date().toISOString(),
    expires_at: new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString(),
    execution_time_ms: 45.2
  }
};
```

### **2. Testing Utilities**

```typescript
// utils/testUtils.ts
export const renderWithPlaybook = (
  component: React.ReactElement,
  mockPlaybook: PlaybookResponse
) => {
  const mockStore = configureStore({
    reducer: {
      playbook: playbookSlice.reducer
    },
    preloadedState: {
      playbook: {
        home: {
          data: mockPlaybook,
          loading: false,
          error: null,
          lastFetched: Date.now(),
          expiresAt: Date.now() + 3600000
        }
      }
    }
  });

  return render(
    <Provider store={mockStore}>
      {component}
    </Provider>
  );
};
```

---

## 🚀 **Implementation Checklist**

### **Phase 1: Core Infrastructure**
- [ ] Set up API service layer
- [ ] Create base PersonalizedLayout component
- [ ] Implement Redux store for playbook data
- [ ] Add error boundaries and fallback content

### **Phase 2: Page-Specific Components**
- [ ] Implement HomePage with personalized layout
- [ ] Implement ProductDetailPage with personalized layout
- [ ] Implement WishlistPage with personalized layout
- [ ] Add responsive CSS grid layouts

### **Phase 3: Advanced Features**
- [ ] Add analytics tracking for sections and products
- [ ] Implement lazy loading and performance optimizations
- [ ] Add A/B testing capabilities for different layouts
- [ ] Create admin interface for monitoring playbook performance

### **Phase 4: Testing & Monitoring**
- [ ] Write unit tests for components
- [ ] Add integration tests for API calls
- [ ] Set up error monitoring and alerting
- [ ] Create performance monitoring dashboard

---

This guide provides a complete framework for implementing dynamic product delivery in your frontend application, ensuring that each user sees personalized, AI-generated product recommendations that adapt to their behavior and preferences.

