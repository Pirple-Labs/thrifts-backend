# Docker Staging Environment Setup

This document explains how to set up and use the Docker staging environment for the Thrifts Backend.

## Quick Start

### Prerequisites
- Docker Desktop installed and running
- Git (to clone the repository)

### Starting the Environment

**On Windows (PowerShell):**
```powershell
.\scripts\docker-staging.ps1 start
```

**On Linux/Mac (Bash):**
```bash
./scripts/docker-staging.sh start
```

This will:
1. Build the Rails application container
2. Start PostgreSQL and Redis containers
3. Run database migrations and seed data
4. Start the Rails server

### Accessing the Application

- **Rails App**: http://localhost:3000
- **PostgreSQL**: localhost:5432 (user: postgres, password: password)
- **Redis**: localhost:6379

## Available Commands

### Windows (PowerShell)
```powershell
.\scripts\docker-staging.ps1 [command]
```

### Linux/Mac (Bash)
```bash
./scripts/docker-staging.sh [command]
```

**Commands:**
- `start` - Start the Docker staging environment
- `stop` - Stop the Docker staging environment
- `restart` - Restart the Docker staging environment
- `logs` - Show logs from all services
- `shell` - Open Rails console
- `db` - Open PostgreSQL console
- `clean` - Clean up containers and volumes
- `build` - Rebuild containers from scratch
- `test` - Run Rails tests
- `migrate` - Run database migrations
- `seed` - Seed the database
- `status` - Show container status
- `help` - Show help message

## Manual Docker Commands

If you prefer to use Docker Compose directly:

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Run Rails commands
docker-compose exec web bundle exec rails console
docker-compose exec web bundle exec rails db:migrate

# Stop services
docker-compose down

# Clean up everything
docker-compose down -v
docker system prune -f
```

## Database Configuration

The Docker environment uses:
- **Database**: `thrifts_backend_development`
- **Username**: `postgres`
- **Password**: `password`
- **Host**: `db` (internal Docker network)
- **Port**: `5432`

## Troubleshooting

### Port Conflicts
If you get port conflicts (3000, 5432, 6379), you can modify the ports in `docker-compose.yml`:

```yaml
ports:
  - "3001:3000"  # Use port 3001 instead of 3000
```

### Database Connection Issues
1. Check if PostgreSQL container is running: `docker-compose ps`
2. Check PostgreSQL logs: `docker-compose logs db`
3. Try restarting: `docker-compose restart db`

### Rails Application Issues
1. Check Rails logs: `docker-compose logs web`
2. Rebuild the container: `docker-compose build web`
3. Check if all gems are installed: `docker-compose exec web bundle install`

### Clean Slate
If you need to start completely fresh:
```bash
docker-compose down -v
docker system prune -f
docker-compose up -d
```

## Development Workflow

1. **Start the environment**: `.\scripts\docker-staging.ps1 start`
2. **Make code changes** in your local files (they're mounted into the container)
3. **Test changes** by accessing http://localhost:3000
4. **Run tests**: `.\scripts\docker-staging.ps1 test`
5. **Access Rails console**: `.\scripts\docker-staging.ps1 shell`
6. **Stop when done**: `.\scripts\docker-staging.ps1 stop`

## File Structure

```
├── docker-compose.yml          # Docker services configuration
├── Dockerfile.dev              # Development Docker image
├── config/database.yml         # Database configuration (updated for Docker)
├── scripts/
│   ├── docker-staging.sh       # Bash management script
│   └── docker-staging.ps1      # PowerShell management script
└── DOCKER_SETUP.md            # This file
```

## Next Steps

Once the Docker environment is running, you can:

1. **Test the personalization APIs**:
   - `/api/home/grid`
   - `/api/pdp/layout`
   - `/api/wishlist/layout`
   - `/api/checkout/layout`
   - `/api/profile/top-picks`

2. **Run the playbook generation scripts**:
   ```bash
   docker-compose exec web bundle exec rails runner scripts/generate_and_print_multi_page.rb
   ```

3. **Test with sample data**:
   ```bash
   docker-compose exec web bundle exec rails runner scripts/run_demo_playbook.rb
   ```

4. **Integrate with frontend** using the API endpoints and response formats documented in `docs/FRONTEND_DYNAMIC_PRODUCT_DELIVERY.md`
