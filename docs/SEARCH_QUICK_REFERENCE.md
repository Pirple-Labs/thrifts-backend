# ⚡ Search Integration Quick Reference

## 🚀 **Quick Start**

### **1. Install Dependencies**
```bash
npm install react react-dom typescript @types/react @types/react-dom
```

### **2. Copy Core Files**
- `services/searchApi.ts` - Search API service
- `contexts/SearchContext.tsx` - Search state management
- `components/search/` - Search UI components
- `styles/search.css` - Search styling

### **3. Basic Usage**
```typescript
import { SearchProvider, useSearch } from './contexts/SearchContext';
import { SearchBar } from './components/search/SearchBar';

function App() {
  return (
    <SearchProvider>
      <SearchPage />
    </SearchProvider>
  );
}

function SearchPage() {
  const { state, search } = useSearch();
  
  return (
    <div>
      <SearchBar />
      <SearchResults />
    </div>
  );
}
```

---

## 📡 **Search API Reference**

### **Endpoint**
```
GET /api/demo/personalized-feed?user_id=1&page=search&query=laptop&region=ke&coordination=true
```

### **Search Parameters**
```typescript
interface SearchParams {
  query: string;           // Search query
  user_id: number;         // User ID
  page: 'search';          // Page type
  region: string;          // User region
  coordination?: boolean;  // Enable coordination
  category?: string;       // Filter by category
  price_min?: number;      // Min price filter
  price_max?: number;      // Max price filter
  brand?: string;          // Brand filter
}
```

### **Response Structure**
```typescript
interface SearchResponse {
  demo_info: {
    plan_source: 'llm' | 'control';
    plan_id: string;
  };
  feed: {
    sections: SearchSection[];
  };
  search_results: {
    query: string;
    total_results: number;
    results: Product[];
  };
}
```

---

## 🎨 **Search Components**

### **SearchBar**
```typescript
<SearchBar
  placeholder="Search for products..."
  onSearch={(query) => console.log('Search:', query)}
  showSuggestions={true}
  autoFocus={true}
/>
```

### **SearchResults**
```typescript
<SearchResults />
```

### **SearchFilters**
```typescript
<SearchFilters />
```

---

## 🎯 **Search Features**

### **Auto-Suggestions**
- Real-time suggestions as you type
- Keyboard navigation (Arrow keys, Enter, Escape)
- Click to select suggestions

### **Advanced Filters**
- Category filtering
- Price range filtering
- Brand filtering
- Coordination toggle

### **Coordination Integration**
- Smart product suggestions
- Bundle recommendations
- Use case completion
- Trending products

---

## 🔧 **Search Context API**

### **State**
```typescript
const { state } = useSearch();
// state.query - Current search query
// state.results - Search results
// state.sections - Coordination sections
// state.suggestions - Auto-suggestions
// state.loading - Loading state
// state.error - Error state
// state.filters - Applied filters
// state.coordinationEnabled - Coordination toggle
```

### **Actions**
```typescript
const { search, setFilters, toggleCoordination, clearError } = useSearch();

// Search for products
search('laptop accessories');

// Set filters
setFilters({ category: 'electronics', price_min: 50 });

// Toggle coordination
toggleCoordination();

// Clear errors
clearError();
```

---

## 🎨 **CSS Classes**

### **Search Bar**
```css
.search-bar-container     /* Main container */
.search-input-wrapper     /* Input wrapper */
.search-input            /* Search input */
.search-button           /* Search button */
.search-suggestions      /* Suggestions dropdown */
.suggestion-item         /* Individual suggestion */
.suggestion-item.selected /* Selected suggestion */
```

### **Search Results**
```css
.search-results          /* Results container */
.search-results-section  /* Results section */
.results-grid           /* Results grid */
.search-loading         /* Loading state */
.search-error           /* Error state */
.no-results            /* No results state */
```

### **Search Filters**
```css
.search-filters         /* Filters container */
.filters-header         /* Filters header */
.filter-group          /* Individual filter */
.clear-filters         /* Clear filters button */
.coordination-toggle   /* Coordination toggle */
```

---

## 📱 **Responsive Breakpoints**

```css
/* Mobile */
@media (max-width: 768px) {
  .results-grid {
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  }
}

/* Small Mobile */
@media (max-width: 480px) {
  .search-filters {
    padding: 1rem;
  }
}
```

---

## 🔧 **Configuration**

### **Environment Variables**
```bash
REACT_APP_SEARCH_API_URL=http://localhost:3000/api/demo
REACT_APP_ENABLE_SUGGESTIONS=true
REACT_APP_ENABLE_COORDINATION=true
```

### **Feature Flags**
```typescript
const searchFeatures = {
  suggestions: true,
  coordination: true,
  filters: true,
  autoComplete: true
};
```

---

## 📊 **Search Analytics**

### **Track Search Events**
```typescript
// Track search queries
trackSearchEvent('search_query', {
  query: 'laptop accessories',
  results_count: 25,
  filters_applied: ['category', 'price'],
  coordination_enabled: true
});

// Track suggestion clicks
trackSearchEvent('suggestion_click', {
  suggestion: 'laptop stand',
  position: 2,
  query_length: 6
});

// Track filter usage
trackSearchEvent('filter_applied', {
  filter_type: 'category',
  filter_value: 'electronics',
  results_count: 15
});
```

---

## 🧪 **Testing**

### **Component Test**
```typescript
import { render, screen, fireEvent } from '@testing-library/react';
import { SearchBar } from './SearchBar';

test('handles search input', () => {
  render(<SearchBar />);
  const input = screen.getByPlaceholderText('Search for products...');
  
  fireEvent.change(input, { target: { value: 'laptop' } });
  expect(input).toHaveValue('laptop');
});
```

### **API Test**
```typescript
import { searchApi } from './searchApi';

test('searches products', async () => {
  const response = await searchApi.searchProducts({
    query: 'laptop',
    user_id: 1,
    page: 'search',
    region: 'ke'
  });
  
  expect(response.search_results).toBeDefined();
});
```

---

## 🚨 **Error Handling**

### **API Errors**
```typescript
try {
  const response = await searchApi.searchProducts(params);
} catch (error) {
  console.error('Search API Error:', error);
  // Show fallback UI
}
```

### **Component Errors**
```typescript
function SearchResults() {
  const { state } = useSearch();
  
  if (state.error) {
    return <div>Search error: {state.error}</div>;
  }
  
  return <div>{/* Render results */}</div>;
}
```

---

## 🎯 **Performance Tips**

### **Debounced Search**
```typescript
import { useDebounce } from 'use-debounce';

function SearchBar() {
  const [query, setQuery] = useState('');
  const [debouncedQuery] = useDebounce(query, 300);
  
  useEffect(() => {
    if (debouncedQuery) {
      search(debouncedQuery);
    }
  }, [debouncedQuery]);
}
```

### **Virtual Scrolling**
```typescript
import { FixedSizeList as List } from 'react-window';

<List
  height={600}
  itemCount={results.length}
  itemSize={200}
  itemData={results}
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
  console.log('Search State:', state);
  console.log('Search Results:', results);
}
```

### **React DevTools**
- Install React Developer Tools
- Inspect SearchContext state
- Monitor component re-renders

---

## 📚 **Resources**

### **Documentation**
- [Full Search Integration Guide](./FRONTEND_SEARCH_INTEGRATION.md)
- [Coordination System Docs](./COORDINATION_SYSTEM_DOCUMENTATION.md)
- [API Examples](./API_EXAMPLES_AND_OUTPUTS.md)

### **External Libraries**
- [React](https://reactjs.org/) - UI framework
- [TypeScript](https://www.typescriptlang.org/) - Type safety
- [CSS Grid](https://css-tricks.com/snippets/css/complete-guide-grid/) - Layout

---

## 🎉 **Ready to Search!**

This quick reference gives you everything needed to integrate search functionality with the coordination system. The components are ready, the API is working, and the styling is responsive.

**Start with the basic usage example and expand from there!** 🚀
