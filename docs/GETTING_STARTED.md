# 🚀 Getting Started - Thrifts Backend

## 📋 **Prerequisites**

### **Required Software**
- **Docker Desktop** (Windows/Mac/Linux)
- **Git** for version control
- **PowerShell** (Windows) or **Bash** (Linux/Mac)
- **Code Editor** (VS Code, RubyMine, etc.)

### **System Requirements**
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 10GB free space
- **OS**: Windows 10+, macOS 10.15+, or Ubuntu 18.04+

---

## ⚡ **Quick Setup (5 minutes)**

### **1. Clone the Repository**
```bash
git clone <repository-url>
cd thrifts-backend
```

### **2. Start the Environment**
```bash
# Windows
.\scripts\docker-staging.ps1 start

# Linux/Mac
./scripts/docker-staging.sh start
```

### **3. Verify Setup**
```bash
# Check containers are running
docker-compose ps

# Test the API
curl http://localhost:3000/api/home/grid?region=ke&pickup_only=true
```

**🎉 You're ready to go!** The backend should be running on `http://localhost:3000`

---

## 🛠️ **Detailed Setup**

### **Step 1: Environment Setup**

#### **Docker Installation**
1. Download Docker Desktop from [docker.com](https://docker.com)
2. Install and start Docker Desktop
3. Verify installation: `docker --version`

#### **Repository Setup**
```bash
# Clone the repository
git clone <repository-url>
cd thrifts-backend

# Check Docker is running
docker ps
```

### **Step 2: Database Setup**

#### **Start Services**
```bash
# Start all services (Rails, PostgreSQL, Redis)
docker-compose up -d

# Check service status
docker-compose ps
```

#### **Database Initialization**
```bash
# Create and migrate database
docker-compose exec web bundle exec rails db:create
docker-compose exec web bundle exec rails db:migrate
docker-compose exec web bundle exec rails db:seed
```

### **Step 3: Verify Installation**

#### **Health Checks**
```bash
# Check Rails server
curl http://localhost:3000/api/events -X POST -H "Content-Type: application/json" -d '{"events":[]}'

# Check database connection
docker-compose exec web bundle exec rails runner "puts Product.count"

# Check Redis connection
docker-compose exec web bundle exec rails runner "puts Redis.current.ping"
```

#### **API Testing**
```bash
# Test home grid API
curl "http://localhost:3000/api/home/grid?region=ke&pickup_only=true"

# Test similar products API
curl "http://localhost:3000/api/merchants/shop/similar_public?id=1&product_id=1&limit=4"
```

---

## 🔧 **Development Workflow**

### **Daily Development**

#### **Start Development**
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f web
```

#### **Make Changes**
1. Edit code in your preferred editor
2. Changes are automatically reflected (Rails auto-reload)
3. Check logs for any errors: `docker-compose logs web`

#### **Database Changes**
```bash
# Create new migration
docker-compose exec web bundle exec rails generate migration AddNewField

# Run migrations
docker-compose exec web bundle exec rails db:migrate

# Rollback if needed
docker-compose exec web bundle exec rails db:rollback
```

### **Testing**

#### **Run Tests**
```bash
# Run all tests
docker-compose exec web bundle exec rspec

# Run specific test
docker-compose exec web bundle exec rspec spec/models/product_spec.rb
```

#### **Console Access**
```bash
# Rails console
docker-compose exec web bundle exec rails console

# Database console
docker-compose exec web bundle exec rails dbconsole
```

---

## 📚 **Key Commands**

### **Docker Management**
```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart specific service
docker-compose restart web

# View logs
docker-compose logs -f web

# Execute commands in container
docker-compose exec web <command>
```

### **Rails Commands**
```bash
# Generate new model/controller
docker-compose exec web bundle exec rails generate model Product

# Run migrations
docker-compose exec web bundle exec rails db:migrate

# Seed database
docker-compose exec web bundle exec rails db:seed

# Rails console
docker-compose exec web bundle exec rails console
```

### **Database Commands**
```bash
# Create database
docker-compose exec web bundle exec rails db:create

# Drop database
docker-compose exec web bundle exec rails db:drop

# Reset database (drop, create, migrate, seed)
docker-compose exec web bundle exec rails db:reset
```

---

## 🐛 **Troubleshooting**

### **Common Issues**

#### **Port Already in Use**
```bash
# Check what's using port 3000
netstat -an | findstr :3000

# Stop conflicting services or change port in docker-compose.yml
```

#### **Database Connection Issues**
```bash
# Check database container
docker-compose ps db

# Restart database
docker-compose restart db

# Check database logs
docker-compose logs db
```

#### **Rails Server Not Starting**
```bash
# Check Rails logs
docker-compose logs web

# Restart Rails container
docker-compose restart web

# Check for syntax errors
docker-compose exec web bundle exec rails runner "puts 'Rails is working'"
```

### **Reset Everything**
```bash
# Stop all containers
docker-compose down

# Remove volumes (WARNING: deletes all data)
docker-compose down -v

# Rebuild and start
docker-compose up --build -d
```

---

## 📖 **Next Steps**

### **For Developers**
1. **[API Reference](API_REFERENCE.md)** - Learn about available endpoints
2. **[Code Standards](CODE_STANDARDS.md)** - Understand coding conventions
3. **[Architecture Guide](ARCHITECTURE.md)** - Learn system design

### **For DevOps**
1. **[Deployment Guide](DEPLOYMENT.md)** - Production deployment
2. **[Infrastructure](INFRASTRUCTURE.md)** - Docker and monitoring setup
3. **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions

### **For Product/QA**
1. **[Features Overview](FEATURES_IMPLEMENTED.md)** - What's been built
2. **[Testing Guide](testing_guide.md)** - How to test the system
3. **[Business Logic](BUSINESS_SUMMARY.md)** - Understanding the platform

---

## 🆘 **Getting Help**

### **Documentation**
- Check the `docs/` folder for detailed guides
- Look for specific feature documentation
- Review API examples and outputs

### **Support**
- Check logs: `docker-compose logs web`
- Review troubleshooting guide
- Ask team members for help

### **Useful Resources**
- [Rails Guides](https://guides.rubyonrails.org/)
- [Docker Documentation](https://docs.docker.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

---

*Welcome to the Thrifts backend development team! 🎉*
