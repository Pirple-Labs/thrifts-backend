# Schema API Reference

## Overview

The Schema API provides dynamic product upload capabilities with category-specific field definitions. This enables the frontend to render dynamic forms based on product categories (Fashion, Beauty, Electronics).

## Base URL
```
http://localhost:3000/api
```

## Authentication
Most endpoints require authentication via JWT token in the Authorization header:
```
Authorization: Bearer <jwt_token>
```

## Endpoints

### 1. Get All Schemas
**GET** `/api/schemas`

Get all available schemas with their field definitions.

**Response:**
```json
{
  "success": true,
  "categories": [
    {
      "category": "fashion",
      "schema": {
        "id": "fashion.v1",
        "category": "fashion",
        "version": "v1",
        "description": "Fashion product schema for clothing, shoes, and accessories",
        "active": true,
        "fields": [
          {
            "key": "brand",
            "type": "string",
            "label": "Brand",
            "required": false,
            "placeholder": "e.g., Nike, Adidas, Zara",
            "max_length": 100
          },
          {
            "key": "size",
            "type": "enum",
            "label": "Size",
            "required": true,
            "options": ["XS", "S", "M", "L", "XL", "XXL", "28", "30", "32", "34", "36", "38", "40", "42", "44", "46", "48", "50", "6", "7", "8", "9", "10", "11", "12"]
          },
          {
            "key": "color",
            "type": "string",
            "label": "Color",
            "required": true,
            "placeholder": "e.g., Black, White, Red, Navy Blue",
            "max_length": 50
          },
          {
            "key": "material",
            "type": "string",
            "label": "Material",
            "required": false,
            "placeholder": "e.g., Cotton, Leather, Denim, Polyester",
            "max_length": 100
          }
        ],
        "required_fields": [...],
        "optional_fields": [...],
        "created_at": "2025-09-16T10:00:00Z",
        "updated_at": "2025-09-16T10:00:00Z"
      }
    }
  ]
}
```

### 2. Get Schema by Category
**GET** `/api/schemas?category=fashion`

Get the latest schema for a specific category.

**Parameters:**
- `category` (string, required): Category name (fashion, beauty, electronics)

**Response:**
```json
{
  "success": true,
  "schema": {
    "id": "fashion.v1",
    "category": "fashion",
    "version": "v1",
    "description": "Fashion product schema for clothing, shoes, and accessories",
    "active": true,
    "fields": [...],
    "required_fields": [...],
    "optional_fields": [...],
    "created_at": "2025-09-16T10:00:00Z",
    "updated_at": "2025-09-16T10:00:00Z"
  }
}
```

**Error Response:**
```json
{
  "success": false,
  "error": "No schema found for category: fashion"
}
```

### 3. Create Schema Product (Draft)
**POST** `/api/merchants/products`

Create a new product using schema-based fields. Products are created as drafts and must be published separately.

**Request Body:**
```json
{
  "name": "Nike Air Max 270",
  "price": 15000,
  "description": "Comfortable running shoes",
  "main_image": "https://example.com/image.jpg",
  "category_id": 1,
  "stock": 1,
  "schema_version": "fashion.v1",
  "attributes": {
    "brand": "Nike",
    "size": "M",
    "color": "Black",
    "material": "Mesh"
  }
}
```

**Response:**
```json
{
  "message": "Product created successfully as draft",
  "product": {
    "id": 201,
    "name": "Nike Air Max 270",
    "price": 15000,
    "stock": 1,
    "main_image": "https://example.com/image.jpg",
    "moderation_status": "pending",
    "category_id": 1,
    "created_at": "2025-09-16T10:00:00Z",
    "category_name": "Fashion",
    "brand_name": null,
    "brand_category": null,
    "brand_specialization": null,
    "schema_version": "fashion.v1",
    "status": "draft",
    "attributes": {
      "brand": "Nike",
      "size": "M",
      "color": "Black",
      "material": "Mesh"
    },
    "can_publish": true,
    "validation_errors": []
  }
}
```

### 4. Publish Schema Product
**POST** `/api/merchants/products/:id/publish`

Publish a draft product after validating against schema requirements.

**Response (Success):**
```json
{
  "message": "Product published successfully",
  "product": {
    "id": 201,
    "status": "published",
    "can_publish": true,
    "validation_errors": []
  }
}
```

**Response (Validation Errors):**
```json
{
  "error": "Cannot publish product",
  "validation_errors": [
    "Size is required",
    "Color is required"
  ]
}
```

### 5. Get Product Details
**GET** `/api/merchants/products/:id`

Get product details including schema attributes.

**Response (Schema Product):**
```json
{
  "id": 201,
  "name": "Nike Air Max 270",
  "price": 15000,
  "stock": 1,
  "main_image": "https://example.com/image.jpg",
  "moderation_status": "approved",
  "category_id": 1,
  "created_at": "2025-09-16T10:00:00Z",
  "category_name": "Fashion",
  "brand_name": null,
  "brand_category": null,
  "brand_specialization": null,
  "schema_version": "fashion.v1",
  "status": "published",
  "attributes": {
    "brand": "Nike",
    "size": "M",
    "color": "Black",
    "material": "Mesh"
  },
  "can_publish": true,
  "validation_errors": []
}
```

**Response (Legacy Product):**
```json
{
  "id": 150,
  "name": "Legacy Product",
  "price": 5000,
  "stock": 1,
  "main_image": "https://example.com/image.jpg",
  "moderation_status": "approved",
  "category_id": 1,
  "created_at": "2025-09-15T10:00:00Z",
  "category_name": "Fashion",
  "brand_name": "Nike",
  "brand_category": "sportswear",
  "brand_specialization": "footwear",
  "subcategory": "Shoes",
  "material": "Mesh",
  "style": "Athletic",
  "use_case": "Running",
  "seasonality": "All Season",
  "brand_id": 1,
  "specifications": {
    "weight": "300g",
    "heel_height": "3cm"
  }
}
```

## Field Types

### String Fields
```json
{
  "key": "brand",
  "type": "string",
  "label": "Brand",
  "required": false,
  "placeholder": "e.g., Nike, Adidas",
  "max_length": 100
}
```

### Enum Fields
```json
{
  "key": "size",
  "type": "enum",
  "label": "Size",
  "required": true,
  "options": ["XS", "S", "M", "L", "XL"]
}
```

### Number Fields
```json
{
  "key": "volume",
  "type": "number",
  "label": "Volume (ml)",
  "required": false,
  "min": 1,
  "max": 1000
}
```

### Date Fields
```json
{
  "key": "expiry_date",
  "type": "date",
  "label": "Expiry Date",
  "required": false,
  "min_date": "2025-09-16"
}
```

### Boolean Fields
```json
{
  "key": "warranty",
  "type": "boolean",
  "label": "Has Warranty",
  "required": false
}
```

## Error Handling

### Validation Errors
```json
{
  "error": "Cannot publish product",
  "validation_errors": [
    "Size is required",
    "Color must be at least 3 characters",
    "Expiry Date must be after 2025-09-16"
  ]
}
```

### Schema Not Found
```json
{
  "success": false,
  "error": "Schema not found"
}
```

### Product Not Found
```json
{
  "error": "Product not found"
}
```

### Unauthorized
```json
{
  "error": "Not authorized"
}
```

## Frontend Integration Examples

### 1. Fetch Schema for Category
```javascript
const fetchSchema = async (category) => {
  const response = await fetch(`/api/schemas?category=${category}`);
  const data = await response.json();
  
  if (data.success) {
    return data.schema;
  } else {
    throw new Error(data.error);
  }
};
```

### 2. Create Schema Product
```javascript
const createSchemaProduct = async (productData) => {
  const response = await fetch('/api/merchants/products', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify(productData)
  });
  
  const data = await response.json();
  return data;
};
```

### 3. Publish Product
```javascript
const publishProduct = async (productId) => {
  const response = await fetch(`/api/merchants/products/${productId}/publish`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  
  const data = await response.json();
  return data;
};
```

## Schema Categories

### Fashion (fashion.v1)
- **brand** (string, optional): Brand name
- **size** (enum, required): Size options
- **color** (string, required): Color description
- **material** (string, optional): Material type

### Beauty (beauty.v1)
- **brand** (string, optional): Brand name
- **shade** (string, optional): Shade/variant name
- **volume** (string, optional): Volume/size
- **expiry_date** (date, optional): Expiry date

### Electronics (electronics.v1)
- **brand** (string, optional): Brand name
- **model** (string, optional): Model name
- **ram** (string, optional): RAM specification
- **storage** (string, optional): Storage capacity
- **battery_health** (string, optional): Battery health percentage
- **warranty** (string, optional): Warranty information

## Status Codes

- **200**: Success
- **201**: Created
- **400**: Bad Request
- **401**: Unauthorized
- **403**: Forbidden
- **404**: Not Found
- **422**: Unprocessable Entity
- **500**: Internal Server Error
