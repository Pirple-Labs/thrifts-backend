#!/bin/bash

# Render Deployment Script for Thrifts Backend
# This script helps prepare and deploy the Rails backend to Render

set -e

echo "🚀 Preparing Thrifts Backend for Render Deployment..."

# Check if we're in the right directory
if [ ! -f "Gemfile" ]; then
    echo "❌ Error: Please run this script from the Rails application root directory"
    exit 1
fi

# Check if render.yaml exists
if [ ! -f "render.yaml" ]; then
    echo "❌ Error: render.yaml not found. Please ensure it exists in the root directory"
    exit 1
fi

# Check if RAILS_MASTER_KEY exists
if [ ! -f "config/master.key" ]; then
    echo "❌ Error: config/master.key not found. Please ensure it exists"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Display the RAILS_MASTER_KEY for the user to copy
echo ""
echo "📋 IMPORTANT: Copy your RAILS_MASTER_KEY:"
echo "----------------------------------------"
cat config/master.key
echo "----------------------------------------"
echo ""

# Check if database.yml has production configuration
if grep -q "production:" config/database.yml; then
    echo "✅ Database configuration for production found"
else
    echo "❌ Error: Production database configuration not found in config/database.yml"
    exit 1
fi

# Check if Dockerfile.render exists
if [ -f "Dockerfile.render" ]; then
    echo "✅ Dockerfile.render found"
else
    echo "⚠️  Warning: Dockerfile.render not found. Using standard Ruby deployment"
fi

echo ""
echo "🎯 Next Steps:"
echo "1. Push your code to your Git repository (GitHub, GitLab, or Bitbucket)"
echo "2. Go to https://render.com and create a new Web Service"
echo "3. Connect your Git repository"
echo "4. Set the following environment variables in Render:"
echo "   - RAILS_ENV=production"
echo "   - RAILS_MASTER_KEY=<copy from above>"
echo "   - DATABASE_URL=<will be set automatically if you create a PostgreSQL database>"
echo "   - RAILS_SERVE_STATIC_FILES=true"
echo "   - RAILS_LOG_TO_STDOUT=true"
echo "   - WEB_CONCURRENCY=2"
echo "   - RAILS_MAX_THREADS=5"
echo "   - SOLID_QUEUE_IN_PUMA=true"
echo "   - FRONTEND_URL=https://your-frontend-domain.vercel.app"
echo ""
echo "5. Create a PostgreSQL database in Render"
echo "6. Deploy your service"
echo ""
echo "📖 For detailed instructions, see: docs/RENDER_DEPLOYMENT_GUIDE.md"
echo ""
echo "✨ Ready for deployment!"
