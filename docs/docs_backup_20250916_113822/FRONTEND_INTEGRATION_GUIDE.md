# 🎨 Frontend Integration Guide - Intelligent Shopping Assistant

## 📋 **Overview**

This guide provides complete frontend implementation details for the Intelligent Shopping & Sales Assistant coordination system. It includes React components, styling, state management, and real API integration examples.

---

## 🏗️ **Architecture Overview**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   React App     │    │   API Service   │    │   Rails API     │
│   Components    │───▶│   Layer         │───▶│   Endpoints     │
│   State Mgmt    │    │   HTTP Client   │    │   Coordination  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

---

## 🔧 **Core Components**

### **1. API Service Layer**

```typescript
// services/coordinationApi.ts
interface CoordinationSection {
  id: string;
  title: string;
  reason: string;
  products: Product[];
  count: number;
  bundle?: BundleInfo;
  use_case?: UseCaseInfo;
}

interface Product {
  id: number;
  title: string;
  price_cents: number;
  img: string;
  role?: 'bundle_component' | 'standalone';
  bundle_slot?: string;
  bundle_id?: string;
}

interface BundleInfo {
  bundle_id: string;
  discount_pct: number;
  price_before_cents: number;
  price_after_cents: number;
  savings_cents: number;
}

interface UseCaseInfo {
  template_id: string;
  coverage: {
    completed: number;
    total: number;
    missing_slots: string[];
  };
}

class CoordinationApiService {
  private baseUrl = 'http://localhost:3000/api/demo';

  async getPersonalizedFeed(params: {
    user_id: number;
    page: 'pdp' | 'home' | 'search' | 'profile';
    pid?: number;
    region: string;
  }): Promise<{
    demo_info: any;
    feed: {
      feed_id: string;
      plan_id: string;
      ttl_seconds: number;
      sections: CoordinationSection[];
    };
    summary: {
      total_products: number;
      total_sections: number;
    };
  }> {
    const queryParams = new URLSearchParams({
      user_id: params.user_id.toString(),
      page: params.page,
      region: params.region,
      ...(params.pid && { pid: params.pid.toString() })
    });

    const response = await fetch(`${this.baseUrl}/personalized-feed?${queryParams}`);
    
    if (!response.ok) {
      throw new Error(`API Error: ${response.status}`);
    }

    return response.json();
  }
}

export const coordinationApi = new CoordinationApiService();
```

### **2. React Context for State Management**

```typescript
// contexts/CoordinationContext.tsx
import React, { createContext, useContext, useReducer, useEffect } from 'react';
import { coordinationApi } from '../services/coordinationApi';

interface CoordinationState {
  sections: CoordinationSection[];
  loading: boolean;
  error: string | null;
  feedId: string | null;
  planId: string | null;
}

type CoordinationAction =
  | { type: 'FETCH_START' }
  | { type: 'FETCH_SUCCESS'; payload: { sections: CoordinationSection[]; feedId: string; planId: string } }
  | { type: 'FETCH_ERROR'; payload: string }
  | { type: 'CLEAR_ERROR' };

const initialState: CoordinationState = {
  sections: [],
  loading: false,
  error: null,
  feedId: null,
  planId: null,
};

function coordinationReducer(state: CoordinationState, action: CoordinationAction): CoordinationState {
  switch (action.type) {
    case 'FETCH_START':
      return { ...state, loading: true, error: null };
    case 'FETCH_SUCCESS':
      return {
        ...state,
        loading: false,
        sections: action.payload.sections,
        feedId: action.payload.feedId,
        planId: action.payload.planId,
      };
    case 'FETCH_ERROR':
      return { ...state, loading: false, error: action.payload };
    case 'CLEAR_ERROR':
      return { ...state, error: null };
    default:
      return state;
  }
}

interface CoordinationContextType {
  state: CoordinationState;
  fetchFeed: (params: { user_id: number; page: string; pid?: number; region: string }) => Promise<void>;
  clearError: () => void;
}

const CoordinationContext = createContext<CoordinationContextType | undefined>(undefined);

export function CoordinationProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(coordinationReducer, initialState);

  const fetchFeed = async (params: { user_id: number; page: string; pid?: number; region: string }) => {
    dispatch({ type: 'FETCH_START' });
    try {
      const response = await coordinationApi.getPersonalizedFeed(params);
      dispatch({
        type: 'FETCH_SUCCESS',
        payload: {
          sections: response.feed.sections,
          feedId: response.feed.feed_id,
          planId: response.feed.plan_id,
        },
      });
    } catch (error) {
      dispatch({ type: 'FETCH_ERROR', payload: error.message });
    }
  };

  const clearError = () => {
    dispatch({ type: 'CLEAR_ERROR' });
  };

  return (
    <CoordinationContext.Provider value={{ state, fetchFeed, clearError }}>
      {children}
    </CoordinationContext.Provider>
  );
}

export function useCoordination() {
  const context = useContext(CoordinationContext);
  if (context === undefined) {
    throw new Error('useCoordination must be used within a CoordinationProvider');
  }
  return context;
}
```

---

## 🎨 **UI Components**

### **3. Complete the Look Section**

```typescript
// components/coordination/CompleteTheLookSection.tsx
import React from 'react';
import { ProductCard } from './ProductCard';
import { CoordinationSection } from '../../types/coordination';

interface CompleteTheLookSectionProps {
  section: CoordinationSection;
  onProductClick: (product: Product) => void;
  onAddToCart: (product: Product) => void;
}

export function CompleteTheLookSection({ 
  section, 
  onProductClick, 
  onAddToCart 
}: CompleteTheLookSectionProps) {
  if (section.products.length === 0) {
    return null;
  }

  return (
    <div className="coordination-section complete-the-look">
      <div className="section-header">
        <h3 className="section-title">
          🎯 {section.title}
        </h3>
        <p className="section-reason">{section.reason}</p>
      </div>
      
      <div className="products-grid">
        {section.products.map((product) => (
          <ProductCard
            key={product.id}
            product={product}
            onClick={() => onProductClick(product)}
            onAddToCart={() => onAddToCart(product)}
            showSlot={true}
            slot={product.bundle_slot}
            role={product.role}
          />
        ))}
      </div>
      
      <div className="section-footer">
        <button className="view-all-btn">
          View All Coordinated Items
        </button>
      </div>
    </div>
  );
}
```

### **4. Bundle & Save Section**

```typescript
// components/coordination/BundleAndSaveSection.tsx
import React from 'react';
import { ProductCard } from './ProductCard';
import { CoordinationSection } from '../../types/coordination';

interface BundleAndSaveSectionProps {
  section: CoordinationSection;
  onBundleAdd: (bundleId: string) => void;
  onProductClick: (product: Product) => void;
}

export function BundleAndSaveSection({ 
  section, 
  onBundleAdd, 
  onProductClick 
}: BundleAndSaveSectionProps) {
  if (!section.bundle || section.products.length === 0) {
    return null;
  }

  const { bundle } = section;
  const savingsPercent = bundle.discount_pct;
  const savingsAmount = bundle.savings_cents / 100;
  const originalPrice = bundle.price_before_cents / 100;
  const finalPrice = bundle.price_after_cents / 100;

  return (
    <div className="coordination-section bundle-and-save">
      <div className="section-header">
        <h3 className="section-title">
          💰 {section.title}
        </h3>
        <p className="section-reason">{section.reason}</p>
      </div>
      
      <div className="bundle-container">
        <div className="bundle-products">
          {section.products.map((product) => (
            <ProductCard
              key={product.id}
              product={product}
              onClick={() => onProductClick(product)}
              showSlot={true}
              slot={product.bundle_slot}
              role={product.role}
              compact={true}
            />
          ))}
        </div>
        
        <div className="bundle-pricing">
          <div className="price-breakdown">
            <div className="original-price">${originalPrice.toFixed(2)}</div>
            <div className="discount">-{savingsPercent}%</div>
            <div className="final-price">${finalPrice.toFixed(2)}</div>
          </div>
          
          <div className="savings-highlight">
            You save ${savingsAmount.toFixed(2)}!
          </div>
          
          <button 
            className="add-bundle-btn"
            onClick={() => onBundleAdd(bundle.bundle_id)}
          >
            Add Bundle to Cart
          </button>
        </div>
      </div>
    </div>
  );
}
```

### **5. Use Case Completion Section**

```typescript
// components/coordination/UseCaseCompletionSection.tsx
import React from 'react';
import { ProductCard } from './ProductCard';
import { CoordinationSection } from '../../types/coordination';

interface UseCaseCompletionSectionProps {
  section: CoordinationSection;
  onProductClick: (product: Product) => void;
  onAddToCart: (product: Product) => void;
}

export function UseCaseCompletionSection({ 
  section, 
  onProductClick, 
  onAddToCart 
}: UseCaseCompletionSectionProps) {
  if (!section.use_case || section.products.length === 0) {
    return null;
  }

  const { use_case } = section;
  const { coverage } = use_case;
  const completionPercent = (coverage.completed / coverage.total) * 100;

  return (
    <div className="coordination-section use-case-completion">
      <div className="section-header">
        <h3 className="section-title">
          🏠 {section.title}
        </h3>
        <p className="section-reason">{section.reason}</p>
      </div>
      
      <div className="progress-container">
        <div className="progress-bar">
          <div 
            className="progress-fill" 
            style={{ width: `${completionPercent}%` }}
          />
        </div>
        <div className="progress-text">
          {coverage.completed} of {coverage.total} items complete
        </div>
      </div>
      
      <div className="products-grid">
        {section.products.map((product) => (
          <ProductCard
            key={product.id}
            product={product}
            onClick={() => onProductClick(product)}
            onAddToCart={() => onAddToCart(product)}
            showSlot={true}
            slot={product.bundle_slot}
            role={product.role}
            highlight={true}
          />
        ))}
      </div>
      
      {coverage.missing_slots.length > 0 && (
        <div className="missing-items">
          <h4>Still needed:</h4>
          <div className="missing-slots">
            {coverage.missing_slots.map((slot) => (
              <span key={slot} className="missing-slot">
                {slot}
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
```

### **6. Product Card Component**

```typescript
// components/coordination/ProductCard.tsx
import React from 'react';
import { Product } from '../../types/coordination';

interface ProductCardProps {
  product: Product;
  onClick: () => void;
  onAddToCart: () => void;
  showSlot?: boolean;
  slot?: string;
  role?: string;
  compact?: boolean;
  highlight?: boolean;
}

export function ProductCard({ 
  product, 
  onClick, 
  onAddToCart, 
  showSlot = false,
  slot,
  role,
  compact = false,
  highlight = false
}: ProductCardProps) {
  const price = product.price_cents / 100;
  
  return (
    <div 
      className={`product-card ${compact ? 'compact' : ''} ${highlight ? 'highlight' : ''}`}
      onClick={onClick}
    >
      <div className="product-image">
        <img src={product.img} alt={product.title} />
        {showSlot && slot && (
          <div className="slot-badge">
            {slot}
          </div>
        )}
        {role === 'bundle_component' && (
          <div className="bundle-badge">
            Bundle
          </div>
        )}
      </div>
      
      <div className="product-info">
        <h4 className="product-title">{product.title}</h4>
        <div className="product-price">${price.toFixed(2)}</div>
        
        {!compact && (
          <button 
            className="add-to-cart-btn"
            onClick={(e) => {
              e.stopPropagation();
              onAddToCart();
            }}
          >
            Add to Cart
          </button>
        )}
      </div>
    </div>
  );
}
```

---

## 🎨 **CSS Styling**

### **7. Coordination Styles**

```css
/* styles/coordination.css */

.coordination-section {
  margin: 2rem 0;
  padding: 1.5rem;
  border-radius: 12px;
  background: #f8f9fa;
  border: 1px solid #e9ecef;
}

.section-header {
  margin-bottom: 1.5rem;
}

.section-title {
  font-size: 1.5rem;
  font-weight: 600;
  color: #2c3e50;
  margin: 0 0 0.5rem 0;
}

.section-reason {
  color: #6c757d;
  font-size: 0.9rem;
  margin: 0;
}

/* Complete the Look */
.complete-the-look {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}

.complete-the-look .section-title {
  color: white;
}

.complete-the-look .section-reason {
  color: rgba(255, 255, 255, 0.8);
}

/* Bundle and Save */
.bundle-and-save {
  background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
  color: white;
}

.bundle-and-save .section-title {
  color: white;
}

.bundle-container {
  display: flex;
  gap: 2rem;
  align-items: center;
}

.bundle-products {
  display: flex;
  gap: 1rem;
  flex: 1;
}

.bundle-pricing {
  background: rgba(255, 255, 255, 0.1);
  padding: 1.5rem;
  border-radius: 8px;
  min-width: 200px;
}

.price-breakdown {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 1rem;
}

.original-price {
  text-decoration: line-through;
  opacity: 0.7;
}

.discount {
  background: #28a745;
  color: white;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-size: 0.8rem;
  font-weight: 600;
}

.final-price {
  font-size: 1.5rem;
  font-weight: 700;
}

.savings-highlight {
  color: #28a745;
  font-weight: 600;
  margin-bottom: 1rem;
}

.add-bundle-btn {
  background: #28a745;
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 6px;
  font-weight: 600;
  cursor: pointer;
  width: 100%;
  transition: background-color 0.2s;
}

.add-bundle-btn:hover {
  background: #218838;
}

/* Use Case Completion */
.use-case-completion {
  background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
  color: white;
}

.use-case-completion .section-title {
  color: white;
}

.progress-container {
  margin-bottom: 1.5rem;
}

.progress-bar {
  width: 100%;
  height: 8px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 4px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  background: #28a745;
  transition: width 0.3s ease;
}

.progress-text {
  margin-top: 0.5rem;
  font-size: 0.9rem;
  opacity: 0.9;
}

.missing-items {
  margin-top: 1rem;
  padding: 1rem;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 6px;
}

.missing-items h4 {
  margin: 0 0 0.5rem 0;
  font-size: 1rem;
}

.missing-slots {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.missing-slot {
  background: rgba(255, 255, 255, 0.2);
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-size: 0.8rem;
}

/* Product Grid */
.products-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
  margin-bottom: 1rem;
}

/* Product Card */
.product-card {
  background: white;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  transition: transform 0.2s, box-shadow 0.2s;
  cursor: pointer;
}

.product-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
}

.product-card.highlight {
  border: 2px solid #28a745;
  box-shadow: 0 0 0 4px rgba(40, 167, 69, 0.1);
}

.product-card.compact {
  display: flex;
  align-items: center;
  padding: 0.5rem;
}

.product-card.compact .product-image {
  width: 60px;
  height: 60px;
  margin-right: 0.75rem;
}

.product-image {
  position: relative;
  width: 100%;
  height: 200px;
  overflow: hidden;
}

.product-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.slot-badge {
  position: absolute;
  top: 0.5rem;
  left: 0.5rem;
  background: #007bff;
  color: white;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: capitalize;
}

.bundle-badge {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  background: #28a745;
  color: white;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-size: 0.7rem;
  font-weight: 600;
}

.product-info {
  padding: 1rem;
}

.product-title {
  font-size: 1rem;
  font-weight: 600;
  margin: 0 0 0.5rem 0;
  color: #2c3e50;
  line-height: 1.3;
}

.product-price {
  font-size: 1.25rem;
  font-weight: 700;
  color: #28a745;
  margin-bottom: 0.75rem;
}

.add-to-cart-btn {
  background: #007bff;
  color: white;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 4px;
  font-weight: 600;
  cursor: pointer;
  width: 100%;
  transition: background-color 0.2s;
}

.add-to-cart-btn:hover {
  background: #0056b3;
}

/* Responsive Design */
@media (max-width: 768px) {
  .bundle-container {
    flex-direction: column;
  }
  
  .bundle-pricing {
    min-width: auto;
  }
  
  .products-grid {
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  }
}
```

---

## 🔗 **Integration Examples**

### **8. Product Detail Page Integration**

```typescript
// pages/ProductDetailPage.tsx
import React, { useEffect } from 'react';
import { useCoordination } from '../contexts/CoordinationContext';
import { CompleteTheLookSection } from '../components/coordination/CompleteTheLookSection';
import { BundleAndSaveSection } from '../components/coordination/BundleAndSaveSection';
import { UseCaseCompletionSection } from '../components/coordination/UseCaseCompletionSection';

interface ProductDetailPageProps {
  productId: number;
  userId: number;
  region: string;
}

export function ProductDetailPage({ productId, userId, region }: ProductDetailPageProps) {
  const { state, fetchFeed } = useCoordination();

  useEffect(() => {
    fetchFeed({
      user_id: userId,
      page: 'pdp',
      pid: productId,
      region: region,
    });
  }, [productId, userId, region, fetchFeed]);

  const handleProductClick = (product: Product) => {
    // Navigate to product detail page
    window.location.href = `/products/${product.id}`;
  };

  const handleAddToCart = (product: Product) => {
    // Add product to cart
    console.log('Adding to cart:', product);
  };

  const handleBundleAdd = (bundleId: string) => {
    // Add entire bundle to cart
    console.log('Adding bundle to cart:', bundleId);
  };

  if (state.loading) {
    return <div className="loading">Loading coordination suggestions...</div>;
  }

  if (state.error) {
    return <div className="error">Error: {state.error}</div>;
  }

  return (
    <div className="product-detail-page">
      {/* Main product content */}
      <div className="main-product">
        {/* Product details, images, etc. */}
      </div>

      {/* Coordination sections */}
      <div className="coordination-sections">
        {state.sections.map((section) => {
          switch (section.id) {
            case 'complete_the_look':
              return (
                <CompleteTheLookSection
                  key={section.id}
                  section={section}
                  onProductClick={handleProductClick}
                  onAddToCart={handleAddToCart}
                />
              );
            case 'bundle_and_save':
              return (
                <BundleAndSaveSection
                  key={section.id}
                  section={section}
                  onBundleAdd={handleBundleAdd}
                  onProductClick={handleProductClick}
                />
              );
            case 'use_case_completion':
              return (
                <UseCaseCompletionSection
                  key={section.id}
                  section={section}
                  onProductClick={handleProductClick}
                  onAddToCart={handleAddToCart}
                />
              );
            default:
              return null;
          }
        })}
      </div>
    </div>
  );
}
```

### **9. Home Page Integration**

```typescript
// pages/HomePage.tsx
import React, { useEffect } from 'react';
import { useCoordination } from '../contexts/CoordinationContext';
import { CompleteTheLookSection } from '../components/coordination/CompleteTheLookSection';

interface HomePageProps {
  userId: number;
  region: string;
}

export function HomePage({ userId, region }: HomePageProps) {
  const { state, fetchFeed } = useCoordination();

  useEffect(() => {
    fetchFeed({
      user_id: userId,
      page: 'home',
      region: region,
    });
  }, [userId, region, fetchFeed]);

  return (
    <div className="home-page">
      {/* Other home page content */}
      
      {/* Coordination sections */}
      <div className="coordination-sections">
        {state.sections.map((section) => {
          if (section.id === 'complete_the_look') {
            return (
              <CompleteTheLookSection
                key={section.id}
                section={section}
                onProductClick={(product) => window.location.href = `/products/${product.id}`}
                onAddToCart={(product) => console.log('Add to cart:', product)}
              />
            );
          }
          return null;
        })}
      </div>
    </div>
  );
}
```

---

## 🚀 **App Setup**

### **10. Main App Component**

```typescript
// App.tsx
import React from 'react';
import { CoordinationProvider } from './contexts/CoordinationContext';
import { ProductDetailPage } from './pages/ProductDetailPage';
import { HomePage } from './pages/HomePage';
import './styles/coordination.css';

function App() {
  const [currentPage, setCurrentPage] = React.useState('home');
  const [productId, setProductId] = React.useState<number | null>(null);
  const userId = 1; // In real app, get from auth
  const region = 'ke'; // In real app, get from user location

  return (
    <CoordinationProvider>
      <div className="app">
        <header className="app-header">
          <h1>Intelligent Shopping Assistant</h1>
          <nav>
            <button onClick={() => setCurrentPage('home')}>Home</button>
            <button onClick={() => setCurrentPage('product')}>Product</button>
          </nav>
        </header>

        <main className="app-main">
          {currentPage === 'home' && (
            <HomePage userId={userId} region={region} />
          )}
          {currentPage === 'product' && productId && (
            <ProductDetailPage 
              productId={productId} 
              userId={userId} 
              region={region} 
            />
          )}
        </main>
      </div>
    </CoordinationProvider>
  );
}

export default App;
```

---

## 📱 **Mobile Responsiveness**

### **11. Mobile-Specific Styles**

```css
/* styles/mobile.css */

@media (max-width: 768px) {
  .coordination-section {
    margin: 1rem 0;
    padding: 1rem;
  }
  
  .section-title {
    font-size: 1.25rem;
  }
  
  .products-grid {
    grid-template-columns: repeat(2, 1fr);
    gap: 0.75rem;
  }
  
  .product-card {
    border-radius: 6px;
  }
  
  .product-image {
    height: 150px;
  }
  
  .product-info {
    padding: 0.75rem;
  }
  
  .product-title {
    font-size: 0.9rem;
  }
  
  .product-price {
    font-size: 1.1rem;
  }
  
  .bundle-container {
    flex-direction: column;
    gap: 1rem;
  }
  
  .bundle-pricing {
    padding: 1rem;
  }
  
  .add-bundle-btn {
    padding: 0.75rem;
    font-size: 1rem;
  }
}

@media (max-width: 480px) {
  .products-grid {
    grid-template-columns: 1fr;
  }
  
  .coordination-section {
    padding: 0.75rem;
  }
  
  .section-title {
    font-size: 1.1rem;
  }
}
```

---

## 🧪 **Testing**

### **12. Component Tests**

```typescript
// __tests__/CompleteTheLookSection.test.tsx
import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import { CompleteTheLookSection } from '../components/coordination/CompleteTheLookSection';

const mockSection = {
  id: 'complete_the_look',
  title: 'Complete Your Laptop Setup',
  reason: 'Complete your laptop setup',
  products: [
    {
      id: 398,
      title: 'Aluminum Laptop Stand',
      price_cents: 2500,
      img: 'https://example.com/stand.jpg',
      role: 'bundle_component',
      bundle_slot: 'stand'
    }
  ],
  count: 1
};

test('renders complete the look section', () => {
  const mockOnProductClick = jest.fn();
  const mockOnAddToCart = jest.fn();
  
  render(
    <CompleteTheLookSection
      section={mockSection}
      onProductClick={mockOnProductClick}
      onAddToCart={mockOnAddToCart}
    />
  );
  
  expect(screen.getByText('🎯 Complete Your Laptop Setup')).toBeInTheDocument();
  expect(screen.getByText('Aluminum Laptop Stand')).toBeInTheDocument();
  expect(screen.getByText('$25.00')).toBeInTheDocument();
});

test('handles product click', () => {
  const mockOnProductClick = jest.fn();
  const mockOnAddToCart = jest.fn();
  
  render(
    <CompleteTheLookSection
      section={mockSection}
      onProductClick={mockOnProductClick}
      onAddToCart={mockOnAddToCart}
    />
  );
  
  fireEvent.click(screen.getByText('Aluminum Laptop Stand'));
  expect(mockOnProductClick).toHaveBeenCalledWith(mockSection.products[0]);
});
```

---

## 🚀 **Deployment**

### **13. Environment Configuration**

```typescript
// config/environment.ts
export const config = {
  api: {
    baseUrl: process.env.REACT_APP_API_BASE_URL || 'http://localhost:3000/api/demo',
    timeout: 10000,
  },
  features: {
    coordination: process.env.REACT_APP_ENABLE_COORDINATION === 'true',
    bundles: process.env.REACT_APP_ENABLE_BUNDLES === 'true',
    useCaseCompletion: process.env.REACT_APP_ENABLE_USE_CASE === 'true',
  },
  analytics: {
    enabled: process.env.REACT_APP_ANALYTICS_ENABLED === 'true',
    trackingId: process.env.REACT_APP_ANALYTICS_ID,
  }
};
```

---

## 📊 **Analytics Integration**

### **14. Event Tracking**

```typescript
// utils/analytics.ts
export const trackCoordinationEvent = (event: string, data: any) => {
  if (config.analytics.enabled) {
    // Track coordination events
    gtag('event', event, {
      event_category: 'coordination',
      event_label: data.sectionId,
      value: data.productCount,
      ...data
    });
  }
};

// Usage in components
const handleProductClick = (product: Product) => {
  trackCoordinationEvent('coordination_product_click', {
    sectionId: 'complete_the_look',
    productId: product.id,
    productTitle: product.title,
    productPrice: product.price_cents,
    bundleSlot: product.bundle_slot,
    role: product.role
  });
  
  // Navigate to product
  window.location.href = `/products/${product.id}`;
};
```

---

## 🎯 **Summary**

This frontend integration guide provides:

1. **Complete API Service Layer** - Type-safe API integration
2. **React Context for State Management** - Centralized coordination state
3. **Reusable UI Components** - Modular coordination sections
4. **Responsive CSS Styling** - Mobile-first design
5. **Integration Examples** - Real page implementations
6. **Testing Framework** - Component testing setup
7. **Analytics Integration** - Event tracking for business metrics

**The frontend is ready to consume the coordination API and display intelligent shopping suggestions to customers!** 🚀

