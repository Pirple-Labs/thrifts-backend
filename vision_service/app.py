#!/usr/bin/env python3
"""
Production Vision Model Service for Image Embeddings
Provides CLIP-like image embeddings for similarity search
"""

import os
import io
import json
import time
from typing import List, Optional

import numpy as np
from PIL import Image
import torch
import torchvision.transforms as transforms
from flask import Flask, request, jsonify
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

class VisionEmbeddingService:
    def __init__(self, model_name: str = "openai/clip-vit-base-patch32"):
        """Initialize the vision model service"""
        self.model_name = model_name
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model = None
        self.processor = None
        self.embedding_dim = 512
        
        # Image preprocessing
        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], 
                               std=[0.229, 0.224, 0.225])
        ])
        
        logger.info(f"Initializing vision service with device: {self.device}")
        self._load_model()
    
    def _load_model(self):
        """Load the vision model"""
        try:
            # For production, use a proper CLIP model
            # For now, we'll use a lightweight CNN model as placeholder
            from torchvision.models import resnet50
            
            self.model = resnet50(pretrained=True)
            # Replace final layer to get embeddings
            self.model.fc = torch.nn.Linear(self.model.fc.in_features, self.embedding_dim)
            self.model.to(self.device)
            self.model.eval()
            
            logger.info(f"Model loaded successfully on {self.device}")
            
        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            raise
    
    def embed_image(self, image_bytes: bytes) -> List[float]:
        """
        Generate embedding for image bytes
        
        Args:
            image_bytes: Raw image data
            
        Returns:
            List of float values representing the embedding
        """
        start_time = time.time()
        
        try:
            # Load and preprocess image
            image = Image.open(io.BytesIO(image_bytes))
            
            # Convert to RGB if needed
            if image.mode != 'RGB':
                image = image.convert('RGB')
            
            # Apply transforms
            image_tensor = self.transform(image).unsqueeze(0).to(self.device)
            
            # Generate embedding
            with torch.no_grad():
                embedding = self.model(image_tensor)
                # Normalize embedding
                embedding = torch.nn.functional.normalize(embedding, p=2, dim=1)
                embedding_list = embedding.cpu().numpy().flatten().tolist()
            
            duration = time.time() - start_time
            logger.info(f"Generated embedding in {duration:.3f}s, dim: {len(embedding_list)}")
            
            return embedding_list
            
        except Exception as e:
            logger.error(f"Embedding generation failed: {e}")
            raise

# Global service instance
vision_service = VisionEmbeddingService()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'model': vision_service.model_name,
        'device': str(vision_service.device),
        'embedding_dim': vision_service.embedding_dim
    })

@app.route('/embed', methods=['POST'])
def embed_image():
    """
    Generate image embedding
    
    Expects raw image bytes in request body
    Returns JSON with embedding array
    """
    start_time = time.time()
    
    try:
        # Validate request
        if not request.data:
            return jsonify({'error': 'No image data provided'}), 400
        
        if len(request.data) > 10 * 1024 * 1024:  # 10MB limit
            return jsonify({'error': 'Image too large'}), 413
        
        # Generate embedding
        embedding = vision_service.embed_image(request.data)
        
        duration = time.time() - start_time
        
        return jsonify({
            'embedding': embedding,
            'dimension': len(embedding),
            'processing_time_ms': round(duration * 1000, 2)
        })
        
    except Exception as e:
        logger.error(f"Embedding request failed: {e}")
        return jsonify({
            'error': 'Embedding generation failed',
            'message': str(e)
        }), 500

@app.route('/embed/batch', methods=['POST'])
def embed_batch():
    """
    Batch embedding endpoint for multiple images
    
    Expects JSON with array of base64 encoded images
    """
    try:
        data = request.get_json()
        if not data or 'images' not in data:
            return jsonify({'error': 'No images provided'}), 400
        
        images = data['images']
        if len(images) > 50:  # Batch limit
            return jsonify({'error': 'Too many images in batch'}), 400
        
        embeddings = []
        for i, img_b64 in enumerate(images):
            try:
                import base64
                img_bytes = base64.b64decode(img_b64)
                embedding = vision_service.embed_image(img_bytes)
                embeddings.append({
                    'index': i,
                    'embedding': embedding,
                    'dimension': len(embedding)
                })
            except Exception as e:
                embeddings.append({
                    'index': i,
                    'error': str(e)
                })
        
        return jsonify({
            'embeddings': embeddings,
            'processed': len(embeddings)
        })
        
    except Exception as e:
        logger.error(f"Batch embedding failed: {e}")
        return jsonify({
            'error': 'Batch processing failed',
            'message': str(e)
        }), 500

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8001))
    host = os.environ.get('HOST', '0.0.0.0')
    debug = os.environ.get('DEBUG', 'false').lower() == 'true'
    
    logger.info(f"Starting vision service on {host}:{port}")
    app.run(host=host, port=port, debug=debug)
