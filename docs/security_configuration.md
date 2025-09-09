# Security Configuration - Thrifts MVP

## Overview

Security hardening for the Thrifts personalization system covering database access, TLS, authentication, and operational security.

## 1. Database Security

### 1.1 PostgreSQL Roles & Permissions

```sql
-- Create application roles with least privilege
CREATE ROLE app_rw LOGIN PASSWORD 'strong_random_password_1';
CREATE ROLE app_ro LOGIN PASSWORD 'strong_random_password_2';
CREATE ROLE analytics_ro LOGIN PASSWORD 'strong_random_password_3';
CREATE ROLE backup_user LOGIN PASSWORD 'strong_random_password_4';

-- Grant schema permissions
GRANT USAGE ON SCHEMA public TO app_rw, app_ro, analytics_ro;

-- OLTP role (read/write for application)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_rw;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_rw;

-- Read-only role for application reads
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_ro;

-- Analytics role (replica only)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO analytics_ro;

-- Backup role
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup_user;
ALTER ROLE backup_user REPLICATION;

-- Set default permissions for new objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
  GRANT USAGE, SELECT ON SEQUENCES TO app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
  GRANT SELECT ON TABLES TO app_ro, analytics_ro, backup_user;

-- Revoke public permissions
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM public;
REVOKE ALL ON SCHEMA public FROM public;
GRANT USAGE ON SCHEMA public TO public;

-- Row Level Security (RLS) for future multi-tenancy
-- ALTER TABLE events ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY events_user_policy ON events
--   FOR ALL TO app_rw
--   USING (user_id = current_setting('app.current_user_id')::bigint);
```

### 1.2 Connection Security

```sql
-- postgresql.conf security settings
ssl = on
ssl_cert_file = '/etc/postgresql/ssl/server.crt'
ssl_key_file = '/etc/postgresql/ssl/server.key'
ssl_ca_file = '/etc/postgresql/ssl/ca.crt'
ssl_crl_file = '/etc/postgresql/ssl/server.crl'

-- Require SSL for all connections
ssl_min_protocol_version = 'TLSv1.2'
ssl_prefer_server_ciphers = on
ssl_ciphers = 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384'

-- Authentication
password_encryption = scram-sha-256
```

### 1.3 pg_hba.conf Configuration

```conf
# TYPE  DATABASE    USER           ADDRESS         METHOD
# Local connections (Unix socket)
local   all         postgres                       peer
local   all         all                           md5

# IPv4 local connections
host    all         postgres       127.0.0.1/32   md5
host    all         app_rw         10.0.0.0/8     scram-sha-256
host    all         app_ro         10.0.0.0/8     scram-sha-256
host    all         analytics_ro   10.0.0.0/8     scram-sha-256
host    all         backup_user    10.0.0.0/8     scram-sha-256

# Replica connections
host    replication backup_user    10.0.0.0/8     scram-sha-256

# Deny all other connections
host    all         all            0.0.0.0/0       reject
```

## 2. Application Security

### 2.1 Rails Configuration

```ruby
# config/environments/production.rb
Rails.application.configure do
  # Force SSL
  config.force_ssl = true
  config.ssl_options = {
    redirect: { exclude: -> request { request.path =~ /health/ } },
    secure_cookies: true,
    hsts: {
      expires: 1.year,
      subdomains: true,
      preload: true
    }
  }
  
  # Security headers
  config.force_ssl = true
  config.session_store :disabled  # API only
  
  # CORS - restrict to known origins
  config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins ['https://thrifts.co.ke', 'https://app.thrifts.co.ke']
      resource '*',
        headers: :any,
        methods: [:get, :post, :put, :patch, :delete, :options, :head],
        expose: ['Authorization'],
        max_age: 86400  # 24 hours
    end
  end
end
```

### 2.2 Environment Variables Management

```bash
# .env.production (use proper secret management in production)
# Database connections
DATABASE_PRIMARY_URL=postgresql://app_rw:PASSWORD@primary-db:5432/thrifts_production?sslmode=require
DATABASE_REPLICA_URL=postgresql://app_ro:PASSWORD@replica-db:5432/thrifts_production?sslmode=require

# Encryption keys
SECRET_KEY_BASE=generate_with_rails_secret
DEVISE_JWT_SECRET_KEY=generate_256_bit_key

# External service credentials
OPERATOR_API_KEY=secure_api_key
SENTRY_API_KEY=secure_api_key
CLOUDINARY_API_KEY=secure_api_key
CLOUDINARY_API_SECRET=secure_secret

# Redis (with AUTH)
REDIS_URL=rediss://username:password@redis-host:6380/0

# Monitoring
DATADOG_API_KEY=monitoring_key
```

### 2.3 API Authentication & Authorization

```ruby
# app/controllers/api/admin/base_controller.rb
module Api
  module Admin
    class BaseController < ApplicationController
      before_action :authenticate_admin!
      
      private
      
      def authenticate_admin!
        # Option 1: Internal admin token
        token = request.headers['X-Admin-Token']
        unless token && ActiveSupport::SecurityUtils.secure_compare(
          token, ENV['ADMIN_API_TOKEN']
        )
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
        
        # Option 2: JWT with admin claims
        # jwt_payload = decode_jwt_token(request.headers['Authorization'])
        # unless jwt_payload&.dig('admin') == true
        #   render json: { error: 'Unauthorized' }, status: :unauthorized
        # end
      end
    end
  end
end
```

### 2.4 Rate Limiting

```ruby
# Gemfile
gem 'rack-attack'

# config/initializers/rack_attack.rb
class Rack::Attack
  # Throttle requests to API endpoints
  throttle('api/feeds/start', limit: 60, period: 1.minute) do |req|
    req.ip if req.path == '/api/feed/start'
  end
  
  throttle('api/events', limit: 1000, period: 1.minute) do |req|
    req.ip if req.path == '/api/events'
  end
  
  throttle('api/admin', limit: 100, period: 1.hour) do |req|
    req.ip if req.path.start_with?('/api/admin')
  end
  
  # Block suspicious activity
  blocklist('block admin scanners') do |req|
    req.path.include?('/admin') && req.user_agent.match?(/scanner|bot/i)
  end
  
  # Safelist trusted IPs
  safelist('allow trusted IPs') do |req|
    ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'].any? do |range|
      IPAddr.new(range).include?(IPAddr.new(req.ip))
    end
  end
end
```

## 3. Infrastructure Security

### 3.1 Network Security

```yaml
# Security Group Rules (AWS)
SecurityGroups:
  DatabaseSG:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Database access
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 5432
          ToPort: 5432
          SourceSecurityGroupId: !Ref ApplicationSG
        - IpProtocol: tcp
          FromPort: 5432
          ToPort: 5432
          SourceSecurityGroupId: !Ref BastionSG
  
  ApplicationSG:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Application servers
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          SourceSecurityGroupId: !Ref LoadBalancerSG
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          SourceSecurityGroupId: !Ref BastionSG
```

### 3.2 Secrets Management

```yaml
# AWS Secrets Manager
DatabaseCredentials:
  Type: AWS::SecretsManager::Secret
  Properties:
    Description: Database credentials
    GenerateSecretString:
      SecretStringTemplate: '{"username": "app_rw"}'
      GenerateStringKey: 'password'
      PasswordLength: 32
      ExcludeCharacters: '"@/\'

ApiKeys:
  Type: AWS::SecretsManager::Secret
  Properties:
    Description: External API keys
    SecretString: !Sub |
      {
        "operator_api_key": "${OperatorApiKey}",
        "cloudinary_api_key": "${CloudinaryApiKey}",
        "cloudinary_api_secret": "${CloudinaryApiSecret}"
      }
```

### 3.3 Container Security

```dockerfile
# Dockerfile security best practices
FROM ruby:3.2-alpine

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Install security updates
RUN apk update && apk upgrade && \
    apk add --no-cache postgresql-dev build-base && \
    rm -rf /var/cache/apk/*

# Set secure permissions
WORKDIR /app
COPY --chown=appuser:appgroup . .

# Install gems with bundler
USER appuser
RUN bundle install --without development test

# Security scanning
RUN bundle audit check

# Run as non-root
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
```

## 4. Monitoring & Incident Response

### 4.1 Security Monitoring

```ruby
# config/initializers/security_logging.rb
Rails.application.configure do
  # Log security events
  config.after_initialize do
    ActiveSupport::Notifications.subscribe('security.unauthorized') do |name, start, finish, id, payload|
      Rails.logger.warn "[SECURITY] Unauthorized access attempt: #{payload.inspect}"
    end
    
    ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, id, payload|
      Rails.logger.warn "[SECURITY] Rate limit triggered: #{payload.inspect}"
    end
  end
end
```

### 4.2 Audit Logging

```sql
-- Enable audit logging for sensitive operations
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Audit configuration
ALTER SYSTEM SET pgaudit.log = 'ddl,write';
ALTER SYSTEM SET pgaudit.log_catalog = off;
ALTER SYSTEM SET pgaudit.log_parameter = on;
SELECT pg_reload_conf();

-- Log admin actions
CREATE OR REPLACE FUNCTION log_admin_action()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_log (
    table_name,
    operation,
    user_name,
    timestamp,
    old_values,
    new_values
  ) VALUES (
    TG_TABLE_NAME,
    TG_OP,
    current_user,
    NOW(),
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN row_to_json(OLD) END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN row_to_json(NEW) END
  );
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Apply to sensitive tables
CREATE TRIGGER audit_experiments
  AFTER INSERT OR UPDATE OR DELETE ON experiments
  FOR EACH ROW EXECUTE FUNCTION log_admin_action();
```

### 4.3 Incident Response

```bash
#!/bin/bash
# security_incident_response.sh

INCIDENT_TYPE="$1"  # breach, unauthorized_access, data_leak
SEVERITY="$2"       # low, medium, high, critical

case "$INCIDENT_TYPE" in
  "breach")
    echo "SECURITY BREACH DETECTED"
    # Immediate actions:
    # 1. Block suspicious IPs
    # 2. Rotate credentials
    # 3. Enable additional logging
    # 4. Notify security team
    ;;
  "unauthorized_access")
    echo "UNAUTHORIZED ACCESS DETECTED"
    # 1. Analyze access logs
    # 2. Check for privilege escalation
    # 3. Verify data integrity
    ;;
  "data_leak")
    echo "DATA LEAK DETECTED"
    # 1. Identify affected data
    # 2. Assess exposure scope
    # 3. Prepare breach notification
    ;;
esac

# Alert security team
curl -X POST "${SLACK_WEBHOOK_URL}" \
  -H 'Content-type: application/json' \
  -d "{
    \"text\": \"🚨 Security Incident: ${INCIDENT_TYPE} (${SEVERITY})\",
    \"channel\": \"#security-alerts\"
  }"
```

## 5. Compliance & Data Protection

### 5.1 GDPR Compliance

```ruby
# app/services/gdpr/data_export_service.rb
module GDPR
  class DataExportService
    def self.export_user_data(user_id)
      {
        user: User.find(user_id).slice(:id, :name, :email, :created_at),
        events: Event.where(user_id: user_id).pluck(:event_name, :timestamp_utc, :page),
        feeds: Feed.where(user_id: user_id).pluck(:feed_uid, :page, :created_at),
        profiles: UserProfile.where(user_id: user_id).pluck(:version, :computed_at),
        experiment_assignments: ExperimentAssignment.where(user_id: user_id)
          .pluck(:experiment_id, :variant, :assigned_at)
      }
    end
  end
  
  class DataDeletionService
    def self.delete_user_data(user_id)
      # Anonymize rather than delete for analytics integrity
      Event.where(user_id: user_id).update_all(user_id: nil)
      Feed.where(user_id: user_id).update_all(user_id: nil)
      ExperimentAssignment.where(user_id: user_id).destroy_all
      UserProfile.where(user_id: user_id).destroy_all
    end
  end
end
```

### 5.2 Data Retention Policies

```ruby
# app/jobs/data_retention_job.rb
class DataRetentionJob < ApplicationJob
  def perform
    # Personal data retention: 2 years after last activity
    inactive_cutoff = 2.years.ago
    
    inactive_users = User.joins(:events)
      .where('events.timestamp_utc < ?', inactive_cutoff)
      .group('users.id')
      .having('MAX(events.timestamp_utc) < ?', inactive_cutoff)
    
    inactive_users.find_each do |user|
      GDPR::DataDeletionService.delete_user_data(user.id)
    end
    
    # Event data: 12 months retention
    Event.where('timestamp_utc < ?', 12.months.ago).delete_all
    
    # Feed data: 30 days retention
    Feed.where('created_at < ?', 30.days.ago).delete_all
  end
end
```

## 6. Security Checklist

### 6.1 Deployment Security

- [ ] TLS 1.2+ enforced for all connections
- [ ] Database connections use SSL with certificate validation
- [ ] Application secrets stored in secure vault (not environment variables)
- [ ] Rate limiting configured for all public endpoints
- [ ] Security headers configured (HSTS, CSP, etc.)
- [ ] Container images scanned for vulnerabilities
- [ ] Database roles follow principle of least privilege
- [ ] Audit logging enabled for sensitive operations
- [ ] Monitoring alerts configured for security events
- [ ] Incident response procedures documented and tested

### 6.2 Regular Security Tasks

```bash
# Weekly security tasks (crontab)
0 2 * * 0 /opt/security/scripts/rotate_secrets.sh
0 3 * * 0 /opt/security/scripts/vulnerability_scan.sh
0 4 * * 0 /opt/security/scripts/access_review.sh

# Monthly security review
# - Review audit logs for anomalies
# - Update security patches
# - Rotate database passwords
# - Review user access permissions
# - Test incident response procedures
```

This security configuration provides comprehensive protection while maintaining operational efficiency for the MVP deployment.
