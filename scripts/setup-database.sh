#!/bin/bash

# Database Setup Script for Docker
set -e

echo "🗄️  Setting up database..."

# Create database if it doesn't exist
echo "Creating database..."
docker-compose exec -T web bundle exec rails db:create

# Run migrations
echo "Running migrations..."
docker-compose exec -T web bundle exec rails db:migrate

# Seed database
echo "Seeding database..."
docker-compose exec -T web bundle exec rails db:seed

echo "✅ Database setup complete!"
