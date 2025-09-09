# Vision Model Service

Production-ready image embedding service for thrifts personalization system.

## Features

- **CLIP-like Image Embeddings**: 512-dimensional vectors for similarity search
- **Performance Optimized**: GPU acceleration when available, CPU fallback
- **Production Ready**: Health checks, logging, error handling
- **Batch Processing**: Support for multiple images in single request
- **Docker Containerized**: Easy deployment and scaling

## Quick Start

### Development
```bash
# Install dependencies
pip install -r requirements.txt

# Run development server
python app.py
```

### Production (Docker)
```bash
# Build and run
docker-compose up -d

# Check health
curl http://localhost:8001/health

# Test embedding
curl -X POST http://localhost:8001/embed \
  --data-binary @test_image.jpg \
  -H "Content-Type: application/octet-stream"
```

## API Endpoints

### `GET /health`
Health check endpoint
- Returns service status and model info

### `POST /embed`
Generate embedding for single image
- **Input**: Raw image bytes in request body
- **Output**: JSON with embedding array
- **Limits**: 10MB max image size

### `POST /embed/batch`
Generate embeddings for multiple images
- **Input**: JSON with base64 encoded images
- **Output**: JSON with embeddings array
- **Limits**: 50 images max per batch

## Performance

- **Target Latency**: <250ms per image (p95)
- **Throughput**: 10-20 images/second
- **Memory Usage**: ~1GB base + model size
- **Cache Hit Rate**: 60%+ after warm-up

## Configuration

Environment variables:

- `MODEL_NAME`: Vision model to use (default: openai/clip-vit-base-patch32)
- `PORT`: Service port (default: 8001)
- `DEBUG`: Enable debug logging (default: false)
- `PYTHONUNBUFFERED`: Unbuffered Python output (recommended: 1)

## Monitoring

The service provides:
- Health check endpoint (`/health`)
- Structured logging
- Performance metrics in response
- Error tracking and fallback handling

## Integration

Used by Rails `ImageEmbedder` service:
- Automatic fallback to OpenAI on failure
- Redis + PostgreSQL caching
- Performance tracking and monitoring

## Deployment

### Staging
```bash
# Build for staging
docker build -t vision-service:staging .
docker run -p 8001:8001 vision-service:staging
```

### Production
```bash
# Scale with multiple workers
docker-compose up -d --scale vision-service=3

# Use with load balancer
# Configure health checks on /health endpoint
```

## Troubleshooting

### Common Issues
1. **Model loading fails**: Check available memory and model name
2. **CUDA errors**: Ensure GPU drivers are installed
3. **Image processing fails**: Verify image format (JPEG, PNG supported)
4. **High latency**: Check if GPU acceleration is working

### Logs
```bash
# View logs
docker-compose logs -f vision-service

# Check health
curl http://localhost:8001/health
```
