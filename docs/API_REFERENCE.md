# 📡 API Reference - Thrifts Backend

## 🌐 **Base URL**
```
Development: http://localhost:3000
Production: https://api.thrifts.com
```

---

## 🔐 **Authentication**

### **JWT Token Authentication**
```http
Authorization: Bearer <jwt_token>
```

### **Public Endpoints**
These endpoints don't require authentication:
- `GET /api/home/grid`
- `GET /api/merchants/shop/similar_public`
- `POST /api/events`

---

## 🏠 **Home & Feed APIs**

### **GET /api/home/grid**
Get personalized home page content with AI-generated playbooks.

**Parameters:**
- `region` (string, optional): User region (default: "ke")
- `pickup_only` (boolean, optional): Filter for pickup-only products

**Example Request:**
```bash
curl "http://localhost:3000/api/home/grid?region=ke&pickup_only=true"
```

**Response:**
```json
{
  "page": "home",
  "layout": {
    "trending_strip": {
      "id": "trending_near_you",
      "title": "Trending Near You",
      "type": "horizontal",
      "items": [
        {
          "id": 196,
          "name": "Women Dresses 42",
          "price": "89.85",
          "image_url": "https://res.cloudinary.com/...",
          "shop": {
            "id": 1,
            "name": "Jesse's Shop",
            "store_logo_url": null
          }
        }
      ]
    }
  },
  "analytics": {
    "playbook_id": "pb_123",
    "generated_at": "2025-01-15T10:30:00Z"
  }
}
```

---

## 🛍️ **Product APIs**

### **GET /api/merchants/shop/similar_public**
Get similar products from the same shop for cross-selling.

**Parameters:**
- `id` (integer, required): Shop ID
- `product_id` (integer, required): Product ID to find similar products for
- `limit` (integer, optional): Number of products (default: 4, max: 20)
- `page` (integer, optional): Page number (default: 1)
- `category_id` (integer, optional): Override category filter
- `brand` (string, optional): Override brand filter

**Example Request:**
```bash
curl "http://localhost:3000/api/merchants/shop/similar_public?id=1&product_id=196&limit=4&page=1"
```

**Response:**
```json
{
  "products": [
    {
      "id": 199,
      "name": "Women Dresses 7",
      "price": "89.98",
      "image_url": "https://res.cloudinary.com/...",
      "shop": {
        "id": 1,
        "name": "Jesse's Shop",
        "store_logo_url": null
      },
      "brand": "Samsung",
      "category_id": 5
    }
  ],
  "page": 1,
  "limit": 4,
  "hasMore": true,
  "total": 15
}
```

### **GET /api/products/:id**
Get detailed product information.

**Parameters:**
- `id` (integer, required): Product ID

**Example Request:**
```bash
curl "http://localhost:3000/api/products/196"
```

**Response:**
```json
{
  "id": 196,
  "name": "Women Dresses 42",
  "price": 89.85,
  "description": "Beautiful dress for special occasions",
  "main_image": "https://res.cloudinary.com/...",
  "supplementary_images": ["https://res.cloudinary.com/..."],
  "stock": 10,
  "shop": {
    "id": 1,
    "name": "Jesse's Shop",
    "store_logo_url": null
  },
  "category": {
    "id": 1,
    "name": "Women's Clothing"
  },
  "brand": {
    "id": 1,
    "name": "Fashion Brand"
  }
}
```

---

## 📊 **Analytics APIs**

### **POST /api/events**
Track user events and behavior for analytics.

**Request Body:**
```json
{
  "events": [
    {
      "event_id": "evt_123",
      "event_name": "page_view",
      "session_id": "sess_456",
      "user_id": 123,
      "page": "home",
      "region": "ke",
      "timestamp_utc": "2025-01-15T10:30:00Z",
      "payload": {
        "product_id": 196,
        "category": "dresses"
      }
    }
  ]
}
```

**Response:**
```json
{
  "accepted": 1,
  "rejected": 0,
  "received_at": "2025-01-15T10:30:01Z"
}
```

### **Event Types**
- `page_view`: User viewed a page
- `product_impression`: Product was displayed to user
- `product_click`: User clicked on a product
- `add_to_cart`: User added product to cart
- `purchase`: User completed a purchase
- `search`: User performed a search
- `filter`: User applied filters

---

## 🏪 **Shop APIs**

### **GET /api/merchants/shop/:id/show_public**
Get public shop information.

**Parameters:**
- `id` (integer, required): Shop ID

**Example Request:**
```bash
curl "http://localhost:3000/api/merchants/shop/1/show_public"
```

**Response:**
```json
{
  "id": 1,
  "name": "Jesse's Shop",
  "description": "Seeded pickup-only shop in Nairobi.",
  "store_logo_url": null,
  "location": "Nairobi",
  "created_at": "2025-01-15T11:26:17Z"
}
```

### **GET /api/merchants/shop/:id/products_public**
Get all products from a specific shop.

**Parameters:**
- `id` (integer, required): Shop ID

**Example Request:**
```bash
curl "http://localhost:3000/api/merchants/shop/1/products_public"
```

**Response:**
```json
[
  {
    "id": 196,
    "name": "Women Dresses 42",
    "price": 89.85,
    "description": "Beautiful dress",
    "stock": 10,
    "main_image": "https://res.cloudinary.com/...",
    "supplementary_images": ["https://res.cloudinary.com/..."],
    "shop": {
      "id": 1,
      "name": "Jesse's Shop",
      "store_logo_url": null
    }
  }
]
```

---

## 🔍 **Search APIs**

### **GET /api/search**
Search for products with various filters.

**Parameters:**
- `q` (string, optional): Search query
- `category_id` (integer, optional): Filter by category
- `shop_id` (integer, optional): Filter by shop
- `min_price` (decimal, optional): Minimum price
- `max_price` (decimal, optional): Maximum price
- `page` (integer, optional): Page number (default: 1)
- `limit` (integer, optional): Results per page (default: 20)

**Example Request:**
```bash
curl "http://localhost:3000/api/search?q=dress&category_id=1&min_price=50&max_price=100"
```

**Response:**
```json
{
  "products": [
    {
      "id": 196,
      "name": "Women Dresses 42",
      "price": "89.85",
      "image_url": "https://res.cloudinary.com/...",
      "shop": {
        "id": 1,
        "name": "Jesse's Shop"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 1,
    "has_more": false
  },
  "filters": {
    "categories": [
      {"id": 1, "name": "Women's Clothing", "count": 1}
    ],
    "shops": [
      {"id": 1, "name": "Jesse's Shop", "count": 1}
    ]
  }
}
```

---

## 👤 **User APIs**

### **POST /api/auth/google_login**
Authenticate user with Google OAuth.

**Request Body:**
```json
{
  "token": "google_oauth_token"
}
```

**Response:**
```json
{
  "user": {
    "id": 123,
    "email": "user@example.com",
    "name": "John Doe"
  },
  "token": "jwt_token_here"
}
```

### **GET /api/users/profile**
Get current user profile (requires authentication).

**Headers:**
```http
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "id": 123,
  "email": "user@example.com",
  "name": "John Doe",
  "created_at": "2025-01-15T10:30:00Z",
  "preferences": {
    "region": "ke",
    "notifications": true
  }
}
```

---

## 🛒 **Cart & Orders APIs**

### **GET /api/users/cart_items**
Get user's cart items (requires authentication).

**Headers:**
```http
Authorization: Bearer <jwt_token>
```

**Response:**
```json
[
  {
    "id": 1,
    "product": {
      "id": 196,
      "name": "Women Dresses 42",
      "price": 89.85,
      "image_url": "https://res.cloudinary.com/..."
    },
    "quantity": 2,
    "added_at": "2025-01-15T10:30:00Z"
  }
]
```

### **POST /api/users/cart_items**
Add item to cart (requires authentication).

**Request Body:**
```json
{
  "product_id": 196,
  "quantity": 1
}
```

**Response:**
```json
{
  "id": 1,
  "product_id": 196,
  "quantity": 1,
  "added_at": "2025-01-15T10:30:00Z"
}
```

---

## 📈 **Analytics & Monitoring**

### **GET /api/health**
Health check endpoint for monitoring.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-01-15T10:30:00Z",
  "services": {
    "database": "healthy",
    "redis": "healthy",
    "ai_service": "healthy"
  }
}
```

### **GET /api/metrics**
Get system performance metrics (admin only).

**Response:**
```json
{
  "api_calls": {
    "total": 1000,
    "success_rate": 99.5,
    "avg_response_time": 150
  },
  "database": {
    "connections": 5,
    "query_time": 25
  },
  "cache": {
    "hit_rate": 95.2,
    "memory_usage": "128MB"
  }
}
```

---

## 🚨 **Error Responses**

### **Standard Error Format**
```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": {
    "field": "Additional error details"
  }
}
```

### **Common HTTP Status Codes**
- `200 OK`: Request successful
- `201 Created`: Resource created successfully
- `400 Bad Request`: Invalid request parameters
- `401 Unauthorized`: Authentication required
- `403 Forbidden`: Access denied
- `404 Not Found`: Resource not found
- `422 Unprocessable Entity`: Validation errors
- `500 Internal Server Error`: Server error

### **Example Error Response**
```json
{
  "error": "Product not found",
  "code": "PRODUCT_NOT_FOUND",
  "details": {
    "product_id": 999
  }
}
```

---

## 🔧 **Rate Limiting**

### **Limits**
- **General APIs**: 1000 requests per hour per IP
- **Authentication APIs**: 10 requests per minute per IP
- **Analytics APIs**: 10000 requests per hour per IP

### **Headers**
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642248000
```

---

## 📝 **API Versioning**

### **Current Version**
All endpoints use version 1 (no version prefix required).

### **Future Versions**
Future versions will use URL prefix: `/api/v2/`

---

*For more detailed examples and integration guides, see the [Frontend Integration Guide](FRONTEND_INTEGRATION_GUIDE.md).*
