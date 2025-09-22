# Complete Docker Reset Script
Write-Host "Complete Docker Reset for Thrifts Backend" -ForegroundColor Red

Write-Host "Step 1: Stopping all containers..." -ForegroundColor Yellow
docker-compose down

Write-Host "Step 2: Removing all volumes..." -ForegroundColor Yellow
docker-compose down -v

Write-Host "Step 3: Removing any orphaned containers..." -ForegroundColor Yellow
docker container prune -f

Write-Host "Step 4: Starting fresh..." -ForegroundColor Yellow
docker-compose up -d

Write-Host "Step 5: Waiting for services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

Write-Host "Step 6: Setting up database..." -ForegroundColor Yellow
docker-compose exec -T web bundle exec rails db:create
docker-compose exec -T web bundle exec rails db:migrate
docker-compose exec -T web bundle exec rails db:seed

Write-Host "✅ Docker environment reset and ready!" -ForegroundColor Green
Write-Host "Rails app: http://localhost:3000" -ForegroundColor Cyan
