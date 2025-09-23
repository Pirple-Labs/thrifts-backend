#!/bin/bash

# Docker Staging Management Script
# Usage: ./scripts/docker-staging.sh [command]

set -e

case "${1:-help}" in
  "start")
    echo "🚀 Starting Docker staging environment..."
    docker-compose up -d
    echo "⏳ Waiting for services to be ready..."
    sleep 10
    echo "📊 Running database setup..."
    docker-compose exec web bundle exec rails db:create db:migrate db:seed
    echo "✅ Docker staging environment is ready!"
    echo "🌐 Rails app: http://localhost:3000"
    echo "🗄️  PostgreSQL: localhost:5432"
    echo "🔴 Redis: localhost:6379"
    ;;
  "stop")
    echo "🛑 Stopping Docker staging environment..."
    docker-compose down
    echo "✅ Docker staging environment stopped!"
    ;;
  "restart")
    echo "🔄 Restarting Docker staging environment..."
    docker-compose down
    docker-compose up -d
    echo "✅ Docker staging environment restarted!"
    ;;
  "logs")
    echo "📋 Showing Docker staging logs..."
    docker-compose logs -f
    ;;
  "shell")
    echo "🐚 Opening Rails console in Docker..."
    docker-compose exec web bundle exec rails console
    ;;
  "db")
    echo "🗄️  Opening database console..."
    docker-compose exec db psql -U postgres -d thrifts_backend_development
    ;;
  "clean")
    echo "🧹 Cleaning up Docker staging environment..."
    docker-compose down -v
    docker system prune -f
    echo "✅ Docker staging environment cleaned!"
    ;;
  "build")
    echo "🔨 Rebuilding Docker staging environment..."
    docker-compose down
    docker-compose build --no-cache
    docker-compose up -d
    echo "✅ Docker staging environment rebuilt!"
    ;;
  "test")
    echo "🧪 Running tests in Docker staging environment..."
    docker-compose exec web bundle exec rails test
    ;;
  "migrate")
    echo "📊 Running database migrations..."
    docker-compose exec web bundle exec rails db:migrate
    echo "✅ Database migrations completed!"
    ;;
  "seed")
    echo "🌱 Seeding database..."
    docker-compose exec web bundle exec rails db:seed
    echo "✅ Database seeded!"
    ;;
  "status")
    echo "📊 Docker staging environment status:"
    docker-compose ps
    ;;
  "help"|*)
    echo "🐳 Docker Staging Management Script"
    echo ""
    echo "Available commands:"
    echo "  start     - Start the Docker staging environment"
    echo "  stop      - Stop the Docker staging environment"
    echo "  restart   - Restart the Docker staging environment"
    echo "  logs      - Show logs from all services"
    echo "  shell     - Open Rails console"
    echo "  db        - Open PostgreSQL console"
    echo "  clean     - Clean up containers and volumes"
    echo "  build     - Rebuild containers from scratch"
    echo "  test      - Run Rails tests"
    echo "  migrate   - Run database migrations"
    echo "  seed      - Seed the database"
    echo "  status    - Show container status"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./scripts/docker-staging.sh start"
    echo "  ./scripts/docker-staging.sh shell"
    echo "  ./scripts/docker-staging.sh logs"
    ;;
esac
