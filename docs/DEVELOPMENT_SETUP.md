# 🛠️ Development Setup - Thrifts Backend

## 📋 **Prerequisites**

### **Required Software**
- **Docker Desktop** 4.0+ (Windows/Mac/Linux)
- **Git** 2.30+
- **PowerShell** 7+ (Windows) or **Bash** 4+ (Linux/Mac)
- **Code Editor** (VS Code, RubyMine, Vim, etc.)

### **System Requirements**
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 15GB free space
- **CPU**: 4 cores recommended
- **OS**: Windows 10+, macOS 10.15+, Ubuntu 18.04+

---

## ⚡ **Quick Setup (5 minutes)**

### **1. Clone Repository**
```bash
git clone <repository-url>
cd thrifts-backend
```

### **2. Start Environment**
```bash
# Windows
.\scripts\docker-staging.ps1 start

# Linux/Mac
./scripts/docker-staging.sh start
```

### **3. Verify Setup**
```bash
# Check containers
docker-compose ps

# Test API
curl http://localhost:3000/api/home/grid?region=ke&pickup_only=true
```

**🎉 Ready to develop!**

---

## 🔧 **Detailed Setup**

### **Step 1: Docker Installation**

#### **Windows**
1. Download Docker Desktop from [docker.com](https://docker.com)
2. Install with WSL2 backend enabled
3. Start Docker Desktop
4. Verify: `docker --version`

#### **macOS**
1. Download Docker Desktop for Mac
2. Install and start Docker Desktop
3. Verify: `docker --version`

#### **Linux (Ubuntu)**
```bash
# Install Docker
sudo apt update
sudo apt install docker.io docker-compose

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
```

### **Step 2: Repository Setup**

#### **Clone and Navigate**
```bash
git clone <repository-url>
cd thrifts-backend

# Check Docker is running
docker ps
```

#### **Environment Configuration**
```bash
# Copy environment template (if exists)
cp .env.example .env

# Edit environment variables
nano .env
```

### **Step 3: Database Setup**

#### **Start Services**
```bash
# Start all services
docker-compose up -d

# Check service status
docker-compose ps
```

#### **Database Initialization**
```bash
# Create database
docker-compose exec web bundle exec rails db:create

# Run migrations
docker-compose exec web bundle exec rails db:migrate

# Seed with sample data
docker-compose exec web bundle exec rails db:seed
```

#### **Verify Database**
```bash
# Check database connection
docker-compose exec web bundle exec rails runner "puts Product.count"

# Check Redis connection
docker-compose exec web bundle exec rails runner "puts Redis.current.ping"
```

---

## 🚀 **Development Workflow**

### **Daily Development**

#### **Start Development Session**
```bash
# Start all services
docker-compose up -d

# View live logs
docker-compose logs -f web

# In another terminal, start your editor
code .
```

#### **Make Code Changes**
1. Edit files in your preferred editor
2. Rails auto-reloads on file changes
3. Check logs for any errors: `docker-compose logs web`
4. Test changes via API or console

#### **Database Operations**
```bash
# Create new migration
docker-compose exec web bundle exec rails generate migration AddNewField

# Run migrations
docker-compose exec web bundle exec rails db:migrate

# Rollback if needed
docker-compose exec web bundle exec rails db:rollback

# Reset database (WARNING: deletes all data)
docker-compose exec web bundle exec rails db:reset
```

### **Testing**

#### **Run Test Suite**
```bash
# Run all tests
docker-compose exec web bundle exec rspec

# Run specific test file
docker-compose exec web bundle exec rspec spec/models/product_spec.rb

# Run with coverage
docker-compose exec web bundle exec rspec --format documentation
```

#### **Manual Testing**
```bash
# Rails console for testing
docker-compose exec web bundle exec rails console

# Test API endpoints
curl -X GET "http://localhost:3000/api/home/grid?region=ke"
curl -X POST "http://localhost:3000/api/events" -H "Content-Type: application/json" -d '{"events":[]}'
```

---

## 🛠️ **Development Tools**

### **Rails Console**
```bash
# Interactive Rails console
docker-compose exec web bundle exec rails console

# One-off commands
docker-compose exec web bundle exec rails runner "puts User.count"
```

### **Database Console**
```bash
# PostgreSQL console
docker-compose exec web bundle exec rails dbconsole

# Direct database access
docker-compose exec db psql -U postgres -d thrifts_backend_development
```

### **Logs and Debugging**
```bash
# View application logs
docker-compose logs -f web

# View database logs
docker-compose logs -f db

# View Redis logs
docker-compose logs -f redis

# Follow all logs
docker-compose logs -f
```

---

## 📁 **Project Structure**

### **Key Directories**
```
thrifts-backend/
├── app/
│   ├── controllers/          # API controllers
│   ├── models/              # Database models
│   ├── services/            # Business logic
│   └── jobs/                # Background jobs
├── config/
│   ├── routes.rb            # API routes
│   ├── database.yml         # Database config
│   └── initializers/        # App configuration
├── db/
│   ├── migrate/             # Database migrations
│   └── seeds.rb             # Sample data
├── docs/                    # Documentation
├── scripts/                 # Development scripts
├── docker-compose.yml       # Container orchestration
└── Dockerfile.dev           # Development container
```

### **Important Files**
- `docker-compose.yml`: Container configuration
- `config/routes.rb`: API endpoint definitions
- `app/controllers/api/`: API controllers
- `app/services/`: Business logic services
- `db/migrate/`: Database schema changes

---

## 🔧 **Configuration**

### **Environment Variables**
```bash
# Database
DATABASE_URL=postgresql://postgres:password@db:5432/thrifts_backend_development

# Redis
REDIS_URL=redis://redis:6379/0

# Rails
RAILS_ENV=development
SECRET_KEY_BASE=your_secret_key

# AI Services (if applicable)
AI_SERVICE_URL=http://ai-service:8000
AI_API_KEY=your_ai_key
```

### **Docker Configuration**
```yaml
# docker-compose.yml key sections
services:
  web:
    build: .
    ports: ["3000:3000"]
    environment:
      - RAILS_ENV=development
    volumes:
      - .:/app
      - /app/node_modules
```

---

## 🐛 **Troubleshooting**

### **Common Issues**

#### **Port Already in Use**
```bash
# Check what's using port 3000
netstat -an | findstr :3000  # Windows
lsof -i :3000                # Mac/Linux

# Stop conflicting services or change port
# Edit docker-compose.yml: ports: ["3001:3000"]
```

#### **Database Connection Issues**
```bash
# Check database container
docker-compose ps db

# Restart database
docker-compose restart db

# Check database logs
docker-compose logs db

# Reset database connection
docker-compose exec web bundle exec rails db:drop db:create db:migrate db:seed
```

#### **Rails Server Not Starting**
```bash
# Check Rails logs
docker-compose logs web

# Restart Rails container
docker-compose restart web

# Check for syntax errors
docker-compose exec web bundle exec rails runner "puts 'Rails is working'"

# Check dependencies
docker-compose exec web bundle install
```

#### **Permission Issues (Linux/Mac)**
```bash
# Fix file permissions
sudo chown -R $USER:$USER .

# Fix Docker permissions
sudo chmod 666 /var/run/docker.sock
```

### **Reset Everything**
```bash
# Stop all containers
docker-compose down

# Remove volumes (WARNING: deletes all data)
docker-compose down -v

# Remove images
docker-compose down --rmi all

# Rebuild everything
docker-compose up --build -d
```

---

## 📚 **Development Scripts**

### **Available Scripts**
```bash
# Windows PowerShell
.\scripts\docker-staging.ps1 start      # Start all services
.\scripts\docker-staging.ps1 stop       # Stop all services
.\scripts\docker-staging.ps1 restart    # Restart all services
.\scripts\docker-staging.ps1 logs       # View logs
.\scripts\docker-staging.ps1 shell      # Open Rails console
.\scripts\docker-staging.ps1 db         # Open database console
.\scripts\docker-staging.ps1 clean      # Clean up containers
.\scripts\docker-staging.ps1 build      # Rebuild containers
.\scripts\docker-staging.ps1 test       # Run tests
.\scripts\docker-staging.ps1 migrate    # Run migrations
.\scripts\docker-staging.ps1 seed       # Seed database

# Linux/Mac Bash
./scripts/docker-staging.sh start       # Start all services
./scripts/docker-staging.sh stop        # Stop all services
./scripts/docker-staging.sh restart     # Restart all services
./scripts/docker-staging.sh logs        # View logs
./scripts/docker-staging.sh shell       # Open Rails console
./scripts/docker-staging.sh db          # Open database console
./scripts/docker-staging.sh clean       # Clean up containers
./scripts/docker-staging.sh build       # Rebuild containers
./scripts/docker-staging.sh test        # Run tests
./scripts/docker-staging.sh migrate     # Run migrations
./scripts/docker-staging.sh seed        # Seed database
```

---

## 🎯 **Best Practices**

### **Code Development**
- **Write tests** for new features
- **Follow Rails conventions** for file structure
- **Use meaningful commit messages**
- **Review code** before merging
- **Document complex logic**

### **Database Management**
- **Always create migrations** for schema changes
- **Test migrations** on sample data
- **Backup data** before major changes
- **Use transactions** for complex operations

### **API Development**
- **Follow RESTful conventions**
- **Validate input parameters**
- **Handle errors gracefully**
- **Document API changes**
- **Version APIs** for breaking changes

### **Docker Usage**
- **Keep containers updated**
- **Use .dockerignore** for efficiency
- **Don't store data in containers**
- **Use volumes** for persistent data
- **Clean up unused images**

---

## 📖 **Next Steps**

### **For New Developers**
1. **[API Reference](API_REFERENCE.md)** - Learn available endpoints
2. **[Architecture Guide](ARCHITECTURE.md)** - Understand system design
3. **[Code Standards](CODE_STANDARDS.md)** - Follow coding conventions

### **For Feature Development**
1. **[Features Overview](FEATURES_IMPLEMENTED.md)** - See what's built
2. **[Testing Guide](testing_guide.md)** - Learn testing practices
3. **[Deployment Guide](DEPLOYMENT.md)** - Deploy your changes

### **For Troubleshooting**
1. **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Common issues
2. **[Monitoring Guide](OPERATIONS/MONITORING.md)** - System health
3. **[Performance Guide](TECHNICAL/PERFORMANCE.md)** - Optimization

---

## 🆘 **Getting Help**

### **Documentation**
- Check the `docs/` folder for detailed guides
- Review API examples and outputs
- Look for specific feature documentation

### **Team Support**
- Ask team members for help
- Use team chat channels
- Schedule pair programming sessions

### **External Resources**
- [Rails Guides](https://guides.rubyonrails.org/)
- [Docker Documentation](https://docs.docker.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

---

*Happy coding! 🚀*
