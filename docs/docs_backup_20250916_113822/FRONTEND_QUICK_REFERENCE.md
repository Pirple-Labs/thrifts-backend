# ⚡ Frontend Quick Reference - Coordination System

## 🚀 **Quick Start**

### **1. Install Dependencies**
```bash
npm install react react-dom typescript @types/react @types/react-dom
```

### **2. Copy Core Files**
- `services/coordinationApi.ts` - API service layer
- `contexts/CoordinationContext.tsx` - State management
- `components/coordination/` - UI components
- `styles/coordination.css` - Styling

### **3. Basic Usage**
```typescript
import { CoordinationProvider, useCoordination } from './contexts/CoordinationContext';

function App() {
  return (
    <CoordinationProvider>
      <ProductPage />
    </CoordinationProvider>
  );
}

function ProductPage() {
  const { state, fetchFeed } = useCoordination();
  
  useEffect(() => {
    fetchFeed({
      user_id: 1,
      page: 'pdp',
      pid: 123,
      region: 'ke'
    });
  }, []);
  
  return (
    <div>
      {state.sections.map(section => (
        <CoordinationSection key={section.id} section={section} />
      ))}
    </div>
  );
}
```

---

## 📡 **API Reference**

### **Endpoint**
```
GET /api/demo/personalized-feed?user_id=1&page=pdp&pid=123&region=ke
```

### **Response Structure**
```typescript
interface ApiResponse {
  demo_info: {
    plan_source: 'llm' | 'control';
    plan_id: string;
  };
  feed: {
    sections: CoordinationSection[];
  };
}
```

### **Section Types**
```typescript
interface CoordinationSection {
  id: 'complete_the_look' | 'bundle_and_save' | 'use_case_completion';
  title: string;
  reason: string;
  products: Product[];
  bundle?: BundleInfo;
  use_case?: UseCaseInfo;
}
```

---

## 🎨 **Component Library**

### **CompleteTheLookSection**
```typescript
<CompleteTheLookSection
  section={section}
  onProductClick={(product) => navigate(`/products/${product.id}`)}
  onAddToCart={(product) => addToCart(product)}
/>
```

### **BundleAndSaveSection**
```typescript
<BundleAndSaveSection
  section={section}
  onBundleAdd={(bundleId) => addBundleToCart(bundleId)}
  onProductClick={(product) => navigate(`/products/${product.id}`)}
/>
```

### **UseCaseCompletionSection**
```typescript
<UseCaseCompletionSection
  section={section}
  onProductClick={(product) => navigate(`/products/${product.id}`)}
  onAddToCart={(product) => addToCart(product)}
/>
```

---

## 🎯 **CSS Classes**

### **Section Classes**
```css
.coordination-section          /* Base section styling */
.complete-the-look            /* Complete the look section */
.bundle-and-save              /* Bundle and save section */
.use-case-completion          /* Use case completion section */
```

### **Product Classes**
```css
.product-card                 /* Base product card */
.product-card.compact         /* Compact product card */
.product-card.highlight       /* Highlighted product card */
.slot-badge                   /* Product slot badge */
.bundle-badge                 /* Bundle component badge */
```

### **Bundle Classes**
```css
.bundle-container             /* Bundle layout container */
.bundle-pricing               /* Bundle pricing section */
.add-bundle-btn               /* Add bundle button */
.savings-highlight            /* Savings amount display */
```

---

## 📱 **Responsive Breakpoints**

```css
/* Mobile */
@media (max-width: 768px) {
  .products-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

/* Small Mobile */
@media (max-width: 480px) {
  .products-grid {
    grid-template-columns: 1fr;
  }
}
```

---

## 🔧 **Configuration**

### **Environment Variables**
```bash
REACT_APP_API_BASE_URL=http://localhost:3000/api/demo
REACT_APP_ENABLE_COORDINATION=true
REACT_APP_ENABLE_BUNDLES=true
REACT_APP_ENABLE_USE_CASE=true
```

### **Feature Flags**
```typescript
const features = {
  coordination: true,
  bundles: true,
  useCaseCompletion: true
};
```

---

## 📊 **Analytics Events**

### **Track Coordination Events**
```typescript
trackCoordinationEvent('coordination_product_click', {
  sectionId: 'complete_the_look',
  productId: 123,
  productTitle: 'Laptop Stand',
  bundleSlot: 'stand',
  role: 'bundle_component'
});
```

### **Event Types**
- `coordination_product_click` - Product clicked
- `coordination_bundle_add` - Bundle added to cart
- `coordination_section_view` - Section viewed
- `coordination_use_case_progress` - Use case progress

---

## 🧪 **Testing**

### **Component Test**
```typescript
import { render, screen } from '@testing-library/react';
import { CompleteTheLookSection } from './CompleteTheLookSection';

test('renders coordination section', () => {
  render(<CompleteTheLookSection section={mockSection} />);
  expect(screen.getByText('Complete Your Laptop Setup')).toBeInTheDocument();
});
```

### **API Test**
```typescript
import { coordinationApi } from './coordinationApi';

test('fetches coordination data', async () => {
  const response = await coordinationApi.getPersonalizedFeed({
    user_id: 1,
    page: 'pdp',
    pid: 123,
    region: 'ke'
  });
  
  expect(response.feed.sections).toBeDefined();
});
```

---

## 🚨 **Error Handling**

### **API Errors**
```typescript
try {
  const response = await coordinationApi.getPersonalizedFeed(params);
} catch (error) {
  console.error('Coordination API Error:', error);
  // Show fallback UI
}
```

### **Component Errors**
```typescript
function CoordinationSection({ section }) {
  if (!section || !section.products) {
    return <div>No coordination data available</div>;
  }
  
  return <div>{/* Render section */}</div>;
}
```

---

## 🎯 **Performance Tips**

### **Lazy Loading**
```typescript
const CompleteTheLookSection = React.lazy(() => 
  import('./components/coordination/CompleteTheLookSection')
);
```

### **Memoization**
```typescript
const MemoizedProductCard = React.memo(ProductCard);
```

### **Virtual Scrolling**
```typescript
import { FixedSizeList as List } from 'react-window';

<List
  height={600}
  itemCount={products.length}
  itemSize={200}
  itemData={products}
>
  {ProductCard}
</List>
```

---

## 🔍 **Debugging**

### **Console Logging**
```typescript
// Enable debug mode
const DEBUG = process.env.NODE_ENV === 'development';

if (DEBUG) {
  console.log('Coordination State:', state);
  console.log('API Response:', response);
}
```

### **React DevTools**
- Install React Developer Tools
- Inspect CoordinationContext state
- Monitor component re-renders

---

## 📚 **Resources**

### **Documentation**
- [Full Integration Guide](./FRONTEND_INTEGRATION_GUIDE.md)
- [API Examples](./API_EXAMPLES_AND_OUTPUTS.md)
- [Business Summary](./BUSINESS_SUMMARY.md)

### **External Libraries**
- [React](https://reactjs.org/) - UI framework
- [TypeScript](https://www.typescriptlang.org/) - Type safety
- [CSS Grid](https://css-tricks.com/snippets/css/complete-guide-grid/) - Layout

---

## 🎉 **Ready to Go!**

This quick reference gives you everything needed to integrate the coordination system into your frontend. The components are ready, the API is working, and the styling is responsive.

**Start with the basic usage example and expand from there!** 🚀





