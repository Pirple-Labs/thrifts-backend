# Docker Staging Management Script (PowerShell)
# Usage: .\scripts\docker-staging.ps1 [command]

param(
    [Parameter(Position=0)]
    [string]$Command = "help"
)

switch ($Command.ToLower()) {
    "start" {
        Write-Host "Starting Docker staging environment..." -ForegroundColor Green
        docker-compose up -d
        Write-Host "Waiting for services to be ready..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        Write-Host "Running database setup..." -ForegroundColor Blue
        docker-compose exec web bundle exec rails db:create db:migrate db:seed
        Write-Host "Docker staging environment is ready!" -ForegroundColor Green
        Write-Host "Rails app: http://localhost:3000" -ForegroundColor Cyan
        Write-Host "PostgreSQL: localhost:5432" -ForegroundColor Cyan
        Write-Host "Redis: localhost:6379" -ForegroundColor Cyan
    }
    "stop" {
        Write-Host "Stopping Docker staging environment..." -ForegroundColor Red
        docker-compose down
        Write-Host "Docker staging environment stopped!" -ForegroundColor Green
    }
    "restart" {
        Write-Host "Restarting Docker staging environment..." -ForegroundColor Yellow
        docker-compose down
        docker-compose up -d
        Write-Host "Docker staging environment restarted!" -ForegroundColor Green
    }
    "logs" {
        Write-Host "Showing Docker staging logs..." -ForegroundColor Blue
        docker-compose logs -f
    }
    "shell" {
        Write-Host "Opening Rails console in Docker..." -ForegroundColor Blue
        docker-compose exec web bundle exec rails console
    }
    "db" {
        Write-Host "Opening database console..." -ForegroundColor Blue
        docker-compose exec db psql -U postgres -d thrifts_backend_development
    }
    "clean" {
        Write-Host "Cleaning up Docker staging environment..." -ForegroundColor Yellow
        docker-compose down -v
        docker system prune -f
        Write-Host "Docker staging environment cleaned!" -ForegroundColor Green
    }
    "build" {
        Write-Host "Rebuilding Docker staging environment..." -ForegroundColor Yellow
        docker-compose down
        docker-compose build --no-cache
        docker-compose up -d
        Write-Host "Docker staging environment rebuilt!" -ForegroundColor Green
    }
    "test" {
        Write-Host "Running tests in Docker staging environment..." -ForegroundColor Blue
        docker-compose exec web bundle exec rails test
    }
    "migrate" {
        Write-Host "Running database migrations..." -ForegroundColor Blue
        docker-compose exec web bundle exec rails db:migrate
        Write-Host "Database migrations completed!" -ForegroundColor Green
    }
    "seed" {
        Write-Host "Seeding database..." -ForegroundColor Blue
        docker-compose exec web bundle exec rails db:seed
        Write-Host "Database seeded!" -ForegroundColor Green
    }
    "status" {
        Write-Host "Docker staging environment status:" -ForegroundColor Blue
        docker-compose ps
    }
    default {
        Write-Host "Docker Staging Management Script" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Available commands:" -ForegroundColor White
        Write-Host "  start     - Start the Docker staging environment" -ForegroundColor Gray
        Write-Host "  stop      - Stop the Docker staging environment" -ForegroundColor Gray
        Write-Host "  restart   - Restart the Docker staging environment" -ForegroundColor Gray
        Write-Host "  logs      - Show logs from all services" -ForegroundColor Gray
        Write-Host "  shell     - Open Rails console" -ForegroundColor Gray
        Write-Host "  db        - Open PostgreSQL console" -ForegroundColor Gray
        Write-Host "  clean     - Clean up containers and volumes" -ForegroundColor Gray
        Write-Host "  build     - Rebuild containers from scratch" -ForegroundColor Gray
        Write-Host "  test      - Run Rails tests" -ForegroundColor Gray
        Write-Host "  migrate   - Run database migrations" -ForegroundColor Gray
        Write-Host "  seed      - Seed the database" -ForegroundColor Gray
        Write-Host "  status    - Show container status" -ForegroundColor Gray
        Write-Host "  help      - Show this help message" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor White
        Write-Host "  .\scripts\docker-staging.ps1 start" -ForegroundColor Gray
        Write-Host "  .\scripts\docker-staging.ps1 shell" -ForegroundColor Gray
        Write-Host "  .\scripts\docker-staging.ps1 logs" -ForegroundColor Gray
    }
}
