# Render Deployment Script for Thrifts Backend (Windows PowerShell)
# This script helps prepare and deploy the Rails backend to Render

Write-Host "🚀 Preparing Thrifts Backend for Render Deployment..." -ForegroundColor Green

# Check if we're in the right directory
if (-not (Test-Path "Gemfile")) {
    Write-Host "❌ Error: Please run this script from the Rails application root directory" -ForegroundColor Red
    exit 1
}

# Check if render.yaml exists
if (-not (Test-Path "render.yaml")) {
    Write-Host "❌ Error: render.yaml not found. Please ensure it exists in the root directory" -ForegroundColor Red
    exit 1
}

# Check if RAILS_MASTER_KEY exists
if (-not (Test-Path "config/master.key")) {
    Write-Host "❌ Error: config/master.key not found. Please ensure it exists" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Prerequisites check passed" -ForegroundColor Green

# Display the RAILS_MASTER_KEY for the user to copy
Write-Host ""
Write-Host "📋 IMPORTANT: Copy your RAILS_MASTER_KEY:" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Yellow
Get-Content "config/master.key"
Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host ""

# Check if database.yml has production configuration
$databaseContent = Get-Content "config/database.yml" -Raw
if ($databaseContent -match "production:") {
    Write-Host "✅ Database configuration for production found" -ForegroundColor Green
} else {
    Write-Host "❌ Error: Production database configuration not found in config/database.yml" -ForegroundColor Red
    exit 1
}

# Check if Dockerfile.render exists
if (Test-Path "Dockerfile.render") {
    Write-Host "✅ Dockerfile.render found" -ForegroundColor Green
} else {
    Write-Host "⚠️  Warning: Dockerfile.render not found. Using standard Ruby deployment" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Push your code to your Git repository"
Write-Host "2. Go to https://render.com and create a new Web Service"
Write-Host "3. Connect your Git repository"
Write-Host "4. Set the following environment variables in Render:"
Write-Host "   - RAILS_ENV=production"
Write-Host "   - RAILS_MASTER_KEY=<copy from above>"
Write-Host "   - DATABASE_URL=<will be set automatically>"
Write-Host "   - RAILS_SERVE_STATIC_FILES=true"
Write-Host "   - RAILS_LOG_TO_STDOUT=true"
Write-Host "   - WEB_CONCURRENCY=2"
Write-Host "   - RAILS_MAX_THREADS=5"
Write-Host "   - SOLID_QUEUE_IN_PUMA=true"
Write-Host "   - FRONTEND_URL=https://your-frontend-domain.vercel.app"
Write-Host ""
Write-Host "5. Create a PostgreSQL database in Render"
Write-Host "6. Deploy your service"
Write-Host ""
Write-Host "📖 For detailed instructions, see: docs/RENDER_DEPLOYMENT_GUIDE.md"
Write-Host ""
Write-Host "✨ Ready for deployment!" -ForegroundColor Green