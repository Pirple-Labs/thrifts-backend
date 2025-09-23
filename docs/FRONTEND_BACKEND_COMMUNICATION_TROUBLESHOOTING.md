# Frontend-Backend Communication Troubleshooting

## 🚨 Common Issues & Solutions

### 1. **Connection Refused Errors**

#### Problem: `net::ERR_CONNECTION_REFUSED`
```
Failed to fetch: net::ERR_CONNECTION_REFUSED
```

#### Solutions:

**Option A: Frontend Running Locally (Recommended)**
```javascript
// Frontend API configuration
const API_BASE_URL = 'http://localhost:3000/api';

// Test connection
fetch(`${API_BASE_URL}/schemas`)
  .then(response => response.json())
  .then(data => console.log('Backend connected:', data))
  .catch(error => console.error('Connection failed:', error));
```

**Option B: Frontend Running in Docker**
```javascript
// Use container name for internal Docker communication
const API_BASE_URL = 'http://thrifts-backend-web-1:3000/api';
```

**Option C: Use host.docker.internal**
```javascript
// For Docker Desktop on Windows/Mac
const API_BASE_URL = 'http://host.docker.internal:3000/api';
```

### 2. **CORS Errors**

#### Problem: `Access to fetch at 'http://localhost:3000/api/schemas' from origin 'http://localhost:5173' has been blocked by CORS policy`

#### Solutions:

**Check CORS Configuration:**
```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:3000',  # Next.js default
           'http://localhost:3001',  # Alternative port
           'http://localhost:5173',  # Vite default
           'http://localhost:8080',  # Vue CLI default
           'http://localhost:4200',  # Angular default
           'http://127.0.0.1:3000',  # Alternative localhost
           'http://127.0.0.1:3001',
           'http://127.0.0.1:5173',
           'http://127.0.0.1:8080',
           'http://127.0.0.1:4200'

    resource '*',
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options, :head],
      expose: ['Authorization'],
      credentials: true
  end
end
```

**Add Your Frontend Port:**
If your frontend runs on a different port, add it to the CORS origins list.

### 3. **Host Not Allowed Errors**

#### Problem: `Blocked host: localhost:3000`

#### Solutions:

**Check Rails Hosts Configuration:**
```ruby
# config/environments/development.rb
config.hosts << "localhost"
config.hosts << "127.0.0.1"
config.hosts << "host.docker.internal"
config.hosts << "host.docker.internal:3000"
config.hosts << "host.docker.internal:5173"
```

### 4. **Docker Networking Issues**

#### Problem: Frontend can't reach backend container

#### Solutions:

**Option A: Use Container Names (Recommended)**
```yaml
# docker-compose.yml
version: '3.8'
services:
  web:
    build: .
    ports:
      - "3000:3000"
    networks:
      - app-network
      
  frontend:
    build: ./frontend
    ports:
      - "5173:5173"
    networks:
      - app-network
    environment:
      - API_BASE_URL=http://web:3000/api

networks:
  app-network:
    driver: bridge
```

**Option B: Use host.docker.internal**
```javascript
// Frontend configuration
const API_BASE_URL = 'http://host.docker.internal:3000/api';
```

### 5. **Authentication Issues**

#### Problem: `401 Unauthorized` or `403 Forbidden`

#### Solutions:

**Check JWT Token:**
```javascript
// Get token from localStorage or auth context
const token = localStorage.getItem('auth_token');

// Include in requests
fetch(`${API_BASE_URL}/merchants/products`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify(productData)
});
```

**Test Authentication:**
```javascript
// Test auth endpoint
fetch(`${API_BASE_URL}/merchants/shop/my_shop`, {
  headers: {
    'Authorization': `Bearer ${token}`
  }
})
.then(response => {
  if (response.ok) {
    console.log('Authentication successful');
  } else {
    console.log('Authentication failed:', response.status);
  }
});
```

## 🔧 **Step-by-Step Troubleshooting**

### Step 1: Verify Backend is Running
```bash
# Check Docker containers
docker-compose ps

# Check backend logs
docker-compose logs web --tail=20

# Test API endpoint
curl http://localhost:3000/api/schemas
```

### Step 2: Test Frontend Connection
```javascript
// Add this to your frontend for testing
const testConnection = async () => {
  try {
    const response = await fetch('http://localhost:3000/api/schemas');
    const data = await response.json();
    console.log('✅ Backend connected:', data);
    return true;
  } catch (error) {
    console.error('❌ Connection failed:', error);
    return false;
  }
};

// Call it
testConnection();
```

### Step 3: Check Network Configuration
```bash
# Check if port 3000 is accessible
netstat -an | findstr :3000

# Test with PowerShell
Invoke-WebRequest -Uri "http://localhost:3000/api/schemas" -Method GET
```

### Step 4: Verify CORS Settings
```bash
# Check CORS headers
curl -H "Origin: http://localhost:5173" \
     -H "Access-Control-Request-Method: GET" \
     -H "Access-Control-Request-Headers: X-Requested-With" \
     -X OPTIONS \
     http://localhost:3000/api/schemas
```

## 🎯 **Frontend Setup Examples**

### React with Vite
```javascript
// vite.config.js
export default {
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
        secure: false
      }
    }
  }
};

// Frontend API service
const API_BASE_URL = '/api'; // Use proxy
```

### Next.js
```javascript
// next.config.js
module.exports = {
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: 'http://localhost:3000/api/:path*'
      }
    ];
  }
};

// Frontend API service
const API_BASE_URL = '/api'; // Use rewrite
```

### Vue.js
```javascript
// vue.config.js
module.exports = {
  devServer: {
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true
      }
    }
  }
};

// Frontend API service
const API_BASE_URL = '/api'; // Use proxy
```

## 🐳 **Docker Setup Examples**

### Option 1: Frontend in Docker (Recommended)
```yaml
# docker-compose.yml
version: '3.8'
services:
  web:
    build: .
    ports:
      - "3000:3000"
    networks:
      - app-network
      
  frontend:
    build: ./frontend
    ports:
      - "5173:5173"
    networks:
      - app-network
    environment:
      - VITE_API_BASE_URL=http://web:3000/api
    depends_on:
      - web

networks:
  app-network:
    driver: bridge
```

```javascript
// Frontend configuration
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://web:3000/api';
```

### Option 2: Frontend Local, Backend Docker
```javascript
// Frontend configuration
const API_BASE_URL = 'http://localhost:3000/api';
```

## 🧪 **Testing Commands**

### Test Backend API
```bash
# Test schemas endpoint
curl http://localhost:3000/api/schemas

# Test with authentication
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     http://localhost:3000/api/merchants/shop/my_shop
```

### Test Frontend Connection
```javascript
// Browser console
fetch('http://localhost:3000/api/schemas')
  .then(response => response.json())
  .then(data => console.log('Success:', data))
  .catch(error => console.error('Error:', error));
```

## 🚨 **Emergency Fixes**

### Quick CORS Fix (Development Only)
```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'  # ⚠️ DANGER: Only for development!
    resource '*',
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options, :head]
  end
end
```

### Quick Host Fix (Development Only)
```ruby
# config/environments/development.rb
config.hosts.clear  # ⚠️ DANGER: Only for development!
```

## 📞 **Getting Help**

If you're still having issues, provide:

1. **Frontend framework** (React, Vue, Angular, etc.)
2. **Frontend port** (3000, 5173, 8080, etc.)
3. **Error messages** (exact text)
4. **Docker setup** (frontend in Docker or local)
5. **Network configuration** (proxy, CORS, etc.)

### Debug Information
```javascript
// Add this to your frontend for debugging
console.log('Frontend URL:', window.location.origin);
console.log('API Base URL:', API_BASE_URL);
console.log('User Agent:', navigator.userAgent);
```
