# Database Setup Script for Docker (PowerShell)
param(
    [switch]$Force
)

Write-Host "Database Setup Script for Docker" -ForegroundColor Cyan

if ($Force) {
    Write-Host "Force mode: Cleaning up first..." -ForegroundColor Yellow
    docker-compose down -v
    docker-compose up -d
    Start-Sleep -Seconds 15
}

Write-Host "Creating database..." -ForegroundColor Blue
docker-compose exec -T web bundle exec rails db:create

Write-Host "Running migrations..." -ForegroundColor Blue
docker-compose exec -T web bundle exec rails db:migrate

Write-Host "Seeding database..." -ForegroundColor Blue
docker-compose exec -T web bundle exec rails db:seed

Write-Host "Database setup complete!" -ForegroundColor Green
