# Frontend Schema Integration Guide

## Overview

This guide explains how to integrate the schema-driven product upload system with your frontend application. The system provides dynamic form generation based on product categories.

## 🎯 Key Features

- **Dynamic Form Generation**: Forms adapt based on selected category
- **Schema Validation**: Real-time validation against category requirements
- **Draft Management**: Save incomplete products and finish later
- **Backward Compatibility**: Existing products continue working
- **QuickPost Mode**: Minimal form for fast product creation

## 🏗️ Architecture

### Backend Components
- **Schema API**: Fetch field definitions for categories
- **Product API**: Create, update, and publish products
- **Validation**: Server-side schema validation
- **Draft System**: Save incomplete products

### Frontend Components
- **SchemaForm**: Dynamic form renderer
- **Field Components**: Input type handlers
- **DraftManager**: Local storage + server sync
- **Validation**: Client-side validation

## 📋 Implementation Steps

### 1. Schema Fetching

```javascript
// Fetch schema for a category
const fetchSchema = async (category) => {
  try {
    const response = await fetch(`/api/schemas?category=${category}`);
    const data = await response.json();
    
    if (data.success) {
      return data.schema;
    } else {
      throw new Error(data.error);
    }
  } catch (error) {
    console.error('Failed to fetch schema:', error);
    throw error;
  }
};

// Usage
const fashionSchema = await fetchSchema('fashion');
console.log(fashionSchema.fields); // Array of field definitions
```

### 2. Dynamic Form Rendering

```javascript
// SchemaForm Component
const SchemaForm = ({ schema, productData, onChange }) => {
  const [formData, setFormData] = useState(productData || {});
  
  const handleFieldChange = (key, value) => {
    const newData = { ...formData, [key]: value };
    setFormData(newData);
    onChange(newData);
  };
  
  const renderField = (field) => {
    const { key, type, label, required, placeholder, options, max_length } = field;
    const value = formData[key] || '';
    
    switch (type) {
      case 'string':
        return (
          <input
            key={key}
            type="text"
            placeholder={placeholder}
            value={value}
            onChange={(e) => handleFieldChange(key, e.target.value)}
            maxLength={max_length}
            required={required}
            className="form-control"
          />
        );
        
      case 'enum':
        return (
          <select
            key={key}
            value={value}
            onChange={(e) => handleFieldChange(key, e.target.value)}
            required={required}
            className="form-control"
          >
            <option value="">Select {label}</option>
            {options.map(option => (
              <option key={option} value={option}>{option}</option>
            ))}
          </select>
        );
        
      case 'number':
        return (
          <input
            key={key}
            type="number"
            placeholder={placeholder}
            value={value}
            onChange={(e) => handleFieldChange(key, parseFloat(e.target.value))}
            min={field.min}
            max={field.max}
            required={required}
            className="form-control"
          />
        );
        
      case 'date':
        return (
          <input
            key={key}
            type="date"
            value={value}
            onChange={(e) => handleFieldChange(key, e.target.value)}
            min={field.min_date}
            max={field.max_date}
            required={required}
            className="form-control"
          />
        );
        
      case 'boolean':
        return (
          <input
            key={key}
            type="checkbox"
            checked={value}
            onChange={(e) => handleFieldChange(key, e.target.checked)}
            className="form-check-input"
          />
        );
        
      default:
        return null;
    }
  };
  
  return (
    <div className="schema-form">
      <h3>{schema.description}</h3>
      {schema.fields.map(field => (
        <div key={field.key} className="form-group">
          <label className="form-label">
            {field.label}
            {field.required && <span className="text-danger"> *</span>}
          </label>
          {renderField(field)}
        </div>
      ))}
    </div>
  );
};
```

### 3. Product Creation

```javascript
// Create schema product
const createSchemaProduct = async (productData) => {
  try {
    const response = await fetch('/api/merchants/products', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify(productData)
    });
    
    const data = await response.json();
    
    if (response.ok) {
      return data;
    } else {
      throw new Error(data.error || 'Failed to create product');
    }
  } catch (error) {
    console.error('Product creation failed:', error);
    throw error;
  }
};

// Usage
const productData = {
  name: 'Nike Air Max 270',
  price: 15000,
  description: 'Comfortable running shoes',
  main_image: 'https://example.com/image.jpg',
  category_id: 1,
  stock: 1,
  schema_version: 'fashion.v1',
  attributes: {
    brand: 'Nike',
    size: 'M',
    color: 'Black',
    material: 'Mesh'
  }
};

const result = await createSchemaProduct(productData);
console.log('Product created:', result.product);
```

### 4. Draft Management

```javascript
// DraftManager for local storage
class DraftManager {
  static saveDraft(productId, data) {
    const drafts = this.getDrafts();
    drafts[productId] = {
      ...data,
      savedAt: new Date().toISOString()
    };
    localStorage.setItem('product_drafts', JSON.stringify(drafts));
  }
  
  static getDraft(productId) {
    const drafts = this.getDrafts();
    return drafts[productId] || null;
  }
  
  static getDrafts() {
    return JSON.parse(localStorage.getItem('product_drafts') || '{}');
  }
  
  static clearDraft(productId) {
    const drafts = this.getDrafts();
    delete drafts[productId];
    localStorage.setItem('product_drafts', JSON.stringify(drafts));
  }
}

// Usage
const draftId = 'draft_' + Date.now();
DraftManager.saveDraft(draftId, formData);

// Later...
const savedDraft = DraftManager.getDraft(draftId);
if (savedDraft) {
  setFormData(savedDraft);
}
```

### 5. Product Publishing

```javascript
// Publish draft product
const publishProduct = async (productId) => {
  try {
    const response = await fetch(`/api/merchants/products/${productId}/publish`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });
    
    const data = await response.json();
    
    if (response.ok) {
      return data;
    } else {
      throw new Error(data.error || 'Failed to publish product');
    }
  } catch (error) {
    console.error('Product publishing failed:', error);
    throw error;
  }
};

// Usage
const result = await publishProduct(productId);
if (result.message) {
  console.log('Product published successfully');
} else {
  console.error('Validation errors:', result.validation_errors);
}
```

## 🎨 Complete Product Upload Flow

```javascript
// Complete product upload component
const ProductUploadForm = () => {
  const [category, setCategory] = useState('');
  const [schema, setSchema] = useState(null);
  const [formData, setFormData] = useState({});
  const [loading, setLoading] = useState(false);
  const [errors, setErrors] = useState([]);
  
  // Fetch schema when category changes
  useEffect(() => {
    if (category) {
      fetchSchema(category)
        .then(setSchema)
        .catch(error => {
          console.error('Failed to fetch schema:', error);
          setErrors([error.message]);
        });
    }
  }, [category]);
  
  // Handle form submission
  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setErrors([]);
    
    try {
      const productData = {
        name: formData.name,
        price: formData.price,
        description: formData.description,
        main_image: formData.main_image,
        category_id: formData.category_id,
        stock: formData.stock || 1,
        schema_version: schema.id,
        attributes: formData.attributes || {}
      };
      
      const result = await createSchemaProduct(productData);
      
      if (result.product.can_publish) {
        // Auto-publish if validation passes
        await publishProduct(result.product.id);
        alert('Product created and published successfully!');
      } else {
        // Save as draft
        alert('Product saved as draft. Complete required fields to publish.');
      }
      
      // Clear form
      setFormData({});
      setCategory('');
      setSchema(null);
      
    } catch (error) {
      setErrors([error.message]);
    } finally {
      setLoading(false);
    }
  };
  
  return (
    <div className="product-upload-form">
      <h2>Upload Product</h2>
      
      {/* Category Selection */}
      <div className="form-group">
        <label>Category</label>
        <select 
          value={category} 
          onChange={(e) => setCategory(e.target.value)}
          className="form-control"
        >
          <option value="">Select Category</option>
          <option value="fashion">Fashion</option>
          <option value="beauty">Beauty</option>
          <option value="electronics">Electronics</option>
        </select>
      </div>
      
      {/* Universal Fields */}
      <div className="form-group">
        <label>Product Name *</label>
        <input
          type="text"
          value={formData.name || ''}
          onChange={(e) => setFormData({...formData, name: e.target.value})}
          className="form-control"
          required
        />
      </div>
      
      <div className="form-group">
        <label>Price (KES) *</label>
        <input
          type="number"
          value={formData.price || ''}
          onChange={(e) => setFormData({...formData, price: parseFloat(e.target.value)})}
          className="form-control"
          required
        />
      </div>
      
      <div className="form-group">
        <label>Description</label>
        <textarea
          value={formData.description || ''}
          onChange={(e) => setFormData({...formData, description: e.target.value})}
          className="form-control"
        />
      </div>
      
      {/* Schema Fields */}
      {schema && (
        <SchemaForm
          schema={schema}
          productData={formData.attributes}
          onChange={(attributes) => setFormData({...formData, attributes})}
        />
      )}
      
      {/* Errors */}
      {errors.length > 0 && (
        <div className="alert alert-danger">
          {errors.map((error, index) => (
            <div key={index}>{error}</div>
          ))}
        </div>
      )}
      
      {/* Submit Button */}
      <button
        type="submit"
        onClick={handleSubmit}
        disabled={loading || !schema}
        className="btn btn-primary"
      >
        {loading ? 'Creating...' : 'Create Product'}
      </button>
    </div>
  );
};
```

## 🔄 QuickPost Mode

```javascript
// QuickPost for minimal friction
const QuickPostForm = () => {
  const [formData, setFormData] = useState({
    name: '',
    price: '',
    category: '',
    image: null
  });
  
  const handleQuickPost = async () => {
    try {
      const productData = {
        name: formData.name,
        price: formData.price,
        category_id: getCategoryId(formData.category),
        main_image: formData.image,
        stock: 1,
        schema_version: getSchemaVersion(formData.category),
        attributes: {} // Empty for QuickPost
      };
      
      const result = await createSchemaProduct(productData);
      alert('Product saved as draft! Complete details later.');
      
    } catch (error) {
      console.error('QuickPost failed:', error);
    }
  };
  
  return (
    <div className="quick-post">
      <h3>Quick Post</h3>
      <input
        type="text"
        placeholder="Product name"
        value={formData.name}
        onChange={(e) => setFormData({...formData, name: e.target.value})}
      />
      <input
        type="number"
        placeholder="Price (KES)"
        value={formData.price}
        onChange={(e) => setFormData({...formData, price: e.target.value})}
      />
      <select
        value={formData.category}
        onChange={(e) => setFormData({...formData, category: e.target.value})}
      >
        <option value="">Select Category</option>
        <option value="fashion">Fashion</option>
        <option value="beauty">Beauty</option>
        <option value="electronics">Electronics</option>
      </select>
      <input
        type="file"
        accept="image/*"
        onChange={(e) => setFormData({...formData, image: e.target.files[0]})}
      />
      <button onClick={handleQuickPost}>Quick Post</button>
    </div>
  );
};
```

## 📱 Product Display

```javascript
// Display schema product attributes
const ProductDisplay = ({ product }) => {
  if (product.schema_product) {
    return (
      <div className="product-details">
        <h2>{product.name}</h2>
        <p>Price: KES {product.price}</p>
        
        {/* Schema Attributes */}
        <div className="schema-attributes">
          <h3>Product Details</h3>
          {Object.entries(product.attributes).map(([key, value]) => (
            <div key={key} className="attribute">
              <strong>{key}:</strong> {value}
            </div>
          ))}
        </div>
      </div>
    );
  } else {
    // Legacy product display
    return (
      <div className="product-details">
        <h2>{product.name}</h2>
        <p>Price: KES {product.price}</p>
        <p>Brand: {product.brand_name}</p>
        <p>Material: {product.material}</p>
        {/* Other legacy fields */}
      </div>
    );
  }
};
```

## 🧪 Testing

```javascript
// Test schema fetching
const testSchemaFetch = async () => {
  try {
    const schema = await fetchSchema('fashion');
    console.log('Schema loaded:', schema);
    console.log('Fields:', schema.fields);
    console.log('Required fields:', schema.required_fields);
  } catch (error) {
    console.error('Test failed:', error);
  }
};

// Test product creation
const testProductCreation = async () => {
  try {
    const productData = {
      name: 'Test Product',
      price: 1000,
      description: 'Test description',
      category_id: 1,
      stock: 1,
      schema_version: 'fashion.v1',
      attributes: {
        brand: 'Test Brand',
        size: 'M',
        color: 'Black'
      }
    };
    
    const result = await createSchemaProduct(productData);
    console.log('Product created:', result);
  } catch (error) {
    console.error('Creation failed:', error);
  }
};
```

## 🚀 Deployment Checklist

- [ ] Test schema fetching for all categories
- [ ] Test product creation with valid data
- [ ] Test product creation with invalid data
- [ ] Test draft management
- [ ] Test product publishing
- [ ] Test validation error handling
- [ ] Test backward compatibility with legacy products
- [ ] Test QuickPost functionality
- [ ] Test form validation
- [ ] Test error handling and user feedback

## 📚 Additional Resources

- [Schema API Reference](./SCHEMA_API_REFERENCE.md)
- [Backend Implementation Guide](./TECHNICAL_IMPLEMENTATION_SUMMARY.md)
- [Database Schema](./ARCHITECTURE.md)

## 🆘 Troubleshooting

### Common Issues

1. **Schema not found**: Check category name spelling
2. **Validation errors**: Ensure required fields are filled
3. **Authentication errors**: Verify JWT token is valid
4. **Network errors**: Check API endpoint URLs
5. **Form not rendering**: Verify schema structure

### Debug Tips

```javascript
// Enable debug logging
const DEBUG = true;

const log = (message, data) => {
  if (DEBUG) {
    console.log(`[Schema] ${message}`, data);
  }
};

// Usage
log('Fetching schema for category:', category);
const schema = await fetchSchema(category);
log('Schema received:', schema);
```
