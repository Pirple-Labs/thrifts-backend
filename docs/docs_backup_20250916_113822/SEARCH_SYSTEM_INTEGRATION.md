# Search System Integration Guide

## Overview

This document describes the complete search system integration, including both text and image search capabilities with your existing vision service.

## Architecture

```
Frontend → Rails API → Search Services → Vision Service → Database
    ↓           ↓            ↓              ↓            ↓
  React    DemoController  SearchFusion  Python Flask  PostgreSQL
           ImageUpload     TextRetriever  Vision Model  pgvector
           Processor       Coordination   ResNet50      ProductEmbeddings
```

## Components

### 1. Vision Service Integration

Your existing Python Flask vision service (`vision_service/app.py`) provides:
- **Endpoint**: `POST /embed` - Generate embeddings from image bytes
- **Model**: ResNet50 with 512-dimensional embeddings
- **Input**: Raw image bytes (application/octet-stream)
- **Output**: JSON with embedding array, dimension, and processing time

### 2. Backend Search Services

#### Text Search
- **SearchTextRetriever**: BM25 + fuzzy matching + vector search
- **SearchFusion**: Hybrid ranking with RRF (Reciprocal Rank Fusion)
- **Integration**: Uses existing coordination features

#### Image Search
- **ImageUploadProcessor**: Handles file uploads and processing
- **ImageEmbedder**: Integrates with your vision service
- **ProductEmbeddingService**: Manages embedding generation and storage

### 3. Database Schema

#### ProductEmbeddings Table
```sql
CREATE TABLE product_embeddings (
  id SERIAL PRIMARY KEY,
  product_id INTEGER REFERENCES products(id),
  embedding_type VARCHAR(20) NOT NULL DEFAULT 'text',
  model_version VARCHAR(20) NOT NULL DEFAULT 'v1.0',
  dimensions INTEGER NOT NULL DEFAULT 512,
  embedding vector(512),
  similarity_score FLOAT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

## API Endpoints

### Text Search
```
GET /api/demo/text-search?query=laptop&user_id=1&region=ke&coordination=true
```

**Parameters:**
- `query` (required): Search query string
- `user_id`: User ID for personalization
- `region`: Region filter (ke, ug, tz)
- `coordination`: Enable coordination features (default: true)
- `category`: Category filter
- `price_band`: Price range filter
- `limit`: Number of results (default: 50)

**Response:**
```json
{
  "demo_info": {
    "page": "search",
    "user_id": 1,
    "region": "ke",
    "search_type": "text",
    "query": "laptop",
    "coordination_enabled": true
  },
  "search_results": {
    "query": "laptop",
    "total_results": 25,
    "products": [...],
    "filters_applied": {...},
    "guardrail_drops": {...}
  }
}
```

### Image Upload Search
```
POST /api/demo/image-search
Content-Type: multipart/form-data

image: [file]
user_id: 1
region: ke
similarity_threshold: 0.7
coordination: true
```

**Parameters:**
- `image` (required): Image file (JPG, PNG, GIF, WebP)
- `user_id`: User ID for personalization
- `region`: Region filter
- `similarity_threshold`: Minimum similarity score (0.0-1.0)
- `coordination`: Enable coordination features

### Image URL Search
```
GET /api/demo/image-search-url?image_url=https://example.com/image.jpg&user_id=1&region=ke&similarity_threshold=0.7
```

**Parameters:**
- `image_url` (required): URL of image to search
- `user_id`: User ID for personalization
- `region`: Region filter
- `similarity_threshold`: Minimum similarity score

## Setup Instructions

### 1. Start Vision Service
```bash
cd vision_service
python app.py
# Service runs on http://localhost:8001
```

### 2. Run Database Migrations
```bash
rails db:migrate
```

### 3. Generate Product Embeddings
```bash
# Test vision service connection
rake embeddings:test_vision_service

# Generate embeddings for all products
rake embeddings:generate_image_embeddings

# Or generate for specific number of products
LIMIT=100 rake embeddings:generate_image_embeddings

# Check embedding statistics
rake embeddings:stats
```

### 4. Test Search Endpoints

#### Text Search Test
```bash
curl "http://localhost:3000/api/demo/text-search?query=laptop&user_id=1&region=ke&coordination=true"
```

#### Image URL Search Test
```bash
curl "http://localhost:3000/api/demo/image-search-url?image_url=https://example.com/image.jpg&user_id=1&region=ke&similarity_threshold=0.7"
```

#### Image Upload Search Test
```bash
curl -X POST \
  -F "image=@/path/to/image.jpg" \
  -F "user_id=1" \
  -F "region=ke" \
  -F "similarity_threshold=0.7" \
  "http://localhost:3000/api/demo/image-search"
```

## Configuration

### Environment Variables

```bash
# Vision Service
VISION_SERVICE_URL=http://127.0.0.1:8001
VISION_MODEL_ENABLED=true

# Image Processing
MAX_IMAGE_UPLOAD_SIZE=10485760  # 10MB
IMAGE_FETCH_TIMEOUT=800         # ms

# Search
TOPK_PER_PHRASE=30
MAX_IMAGE_SIZE=5242880          # 5MB
```

### Vision Service Configuration

Your vision service is configured with:
- **Model**: ResNet50 (512 dimensions)
- **Image Size**: 224x224 pixels
- **Normalization**: ImageNet mean/std
- **Device**: Auto-detect CUDA/CPU

## Performance Considerations

### Vision Service
- **Processing Time**: ~100-300ms per image
- **Memory**: ~2GB for ResNet50 model
- **Batch Processing**: Supports up to 50 images per batch

### Database
- **Vector Index**: HNSW index for fast similarity search
- **Embedding Storage**: 512-dimensional vectors
- **Caching**: Redis + PostgreSQL dual caching

### API Performance
- **Text Search**: <100ms for most queries
- **Image Search**: 200-500ms (including vision processing)
- **Coordination**: Adds ~50ms for intelligent bundling

## Monitoring

### Health Checks
```bash
# Vision service health
curl http://localhost:8001/health

# Embedding statistics
rake embeddings:stats
```

### Logging
- Vision service calls are logged with timing
- Embedding generation progress is tracked
- Search performance metrics are recorded

## Troubleshooting

### Common Issues

1. **Vision Service Not Responding**
   ```bash
   # Check if service is running
   curl http://localhost:8001/health
   
   # Restart service
   cd vision_service && python app.py
   ```

2. **No Embeddings Found**
   ```bash
   # Generate embeddings
   rake embeddings:generate_image_embeddings
   
   # Check coverage
   rake embeddings:stats
   ```

3. **Slow Search Performance**
   ```bash
   # Check database indexes
   rails db:migrate:status
   
   # Monitor vision service performance
   tail -f vision_service/logs/app.log
   ```

### Error Handling

- **Vision Service Down**: Falls back to hash-based embeddings
- **Image Upload Fails**: Returns error with validation details
- **No Similar Products**: Returns empty results with explanation
- **Database Errors**: Logs error and returns graceful fallback

## Development Workflow

### Adding New Search Features

1. **Update Vision Service**: Modify `vision_service/app.py`
2. **Update Backend**: Modify search services in `app/services/personalization/`
3. **Update API**: Add new endpoints in `app/controllers/api/demo_controller.rb`
4. **Test Integration**: Use provided test commands
5. **Update Documentation**: Update this guide

### Testing New Models

1. **Update Vision Service**: Change model in `VisionEmbeddingService`
2. **Regenerate Embeddings**: `FORCE_REGENERATE=true rake embeddings:generate_image_embeddings`
3. **Test Performance**: Compare search quality and speed
4. **Update Configuration**: Adjust similarity thresholds if needed

## Production Deployment

### Vision Service
- Deploy as separate service with load balancing
- Use GPU instances for better performance
- Implement health checks and monitoring

### Database
- Use managed PostgreSQL with pgvector extension
- Implement connection pooling
- Set up automated backups

### Caching
- Use Redis cluster for embedding cache
- Implement cache warming strategies
- Monitor cache hit rates

## Security Considerations

- **File Upload Validation**: Strict file type and size limits
- **URL Validation**: Only allow trusted image sources
- **Rate Limiting**: Implement API rate limits
- **Input Sanitization**: Validate all search parameters

This integration provides a complete search system that leverages your existing vision service while adding comprehensive text search and coordination features.





