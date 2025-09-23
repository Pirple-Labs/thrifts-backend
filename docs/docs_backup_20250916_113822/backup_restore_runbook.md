# Backup & Restore Runbook - Thrifts MVP

## Overview

This runbook covers Point-in-Time Recovery (PITR) setup, backup procedures, and disaster recovery for the Thrifts personalization system.

**RPO Target**: ≤ 5 minutes  
**RTO Target**: ≤ 30 minutes

## 1. Backup Strategy

### 1.1 Continuous WAL Archiving

```bash
# PostgreSQL configuration for WAL archiving
# Add to postgresql.conf:

wal_level = replica
archive_mode = on
archive_command = 'aws s3 cp %p s3://thrifts-db-backups/wal/%f'
archive_timeout = 300  # 5 minutes max

# Ensure WAL files are archived within 5 minutes
max_wal_size = 16GB
checkpoint_timeout = 15min
```

### 1.2 Base Backups (Nightly)

```bash
#!/bin/bash
# backup_script.sh - Run nightly via cron

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/backup_$BACKUP_DATE"
S3_BUCKET="s3://thrifts-db-backups/base"

# Create base backup
pg_basebackup -h localhost -p 5432 -U backup_user \
  -D "$BACKUP_DIR" \
  -P -W -R -X stream

# Compress and upload to S3
tar -czf "/tmp/base_backup_$BACKUP_DATE.tar.gz" -C "$BACKUP_DIR" .
aws s3 cp "/tmp/base_backup_$BACKUP_DATE.tar.gz" "$S3_BUCKET/"

# Cleanup local files
rm -rf "$BACKUP_DIR"
rm "/tmp/base_backup_$BACKUP_DATE.tar.gz"

# Keep only last 30 days of backups
aws s3 ls "$S3_BUCKET/" | grep "base_backup_" | \
  awk '{print $4}' | sort | head -n -30 | \
  xargs -I {} aws s3 rm "$S3_BUCKET/{}"

echo "Backup completed: base_backup_$BACKUP_DATE.tar.gz"
```

### 1.3 Cron Schedule

```bash
# /etc/crontab entries
# Base backup at 2 AM daily
0 2 * * * postgres /opt/thrifts/scripts/backup_script.sh >> /var/log/postgres_backup.log 2>&1

# WAL cleanup (remove archived WAL older than 7 days)
0 3 * * * postgres /opt/thrifts/scripts/wal_cleanup.sh >> /var/log/wal_cleanup.log 2>&1
```

## 2. Restore Procedures

### 2.1 Full Disaster Recovery

**When to use**: Complete database corruption, hardware failure, or data center outage.

```bash
#!/bin/bash
# restore_full.sh - Full disaster recovery

TARGET_TIME="2025-01-15 10:30:00 UTC"  # Point-in-time target
NEW_INSTANCE_IP="10.0.1.100"           # New database server IP
BACKUP_DATE="20250115_020000"          # Latest base backup

# 1. Provision new PostgreSQL instance
# (Manual step - provision new server/RDS instance)

# 2. Download and restore base backup
aws s3 cp "s3://thrifts-db-backups/base/base_backup_$BACKUP_DATE.tar.gz" /tmp/
sudo -u postgres mkdir -p /var/lib/postgresql/14/main_restore
sudo -u postgres tar -xzf /tmp/base_backup_$BACKUP_DATE.tar.gz -C /var/lib/postgresql/14/main_restore

# 3. Create recovery configuration
sudo -u postgres cat > /var/lib/postgresql/14/main_restore/postgresql.conf << EOF
restore_command = 'aws s3 cp s3://thrifts-db-backups/wal/%f %p'
recovery_target_time = '$TARGET_TIME'
recovery_target_action = 'promote'
EOF

# 4. Start PostgreSQL in recovery mode
sudo systemctl stop postgresql
sudo mv /var/lib/postgresql/14/main /var/lib/postgresql/14/main_old
sudo mv /var/lib/postgresql/14/main_restore /var/lib/postgresql/14/main
sudo chown -R postgres:postgres /var/lib/postgresql/14/main
sudo systemctl start postgresql

# 5. Verify recovery
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"
sudo -u postgres psql -c "SELECT current_timestamp;"
```

### 2.2 Point-in-Time Recovery (PITR)

**When to use**: Data corruption, accidental deletion, or rollback to specific time.

```bash
#!/bin/bash
# pitr_restore.sh - Point-in-time recovery to new instance

TARGET_TIME="$1"  # e.g., "2025-01-15 10:30:00 UTC"
BACKUP_DATE="$2"  # e.g., "20250115_020000"

if [ -z "$TARGET_TIME" ] || [ -z "$BACKUP_DATE" ]; then
    echo "Usage: $0 'YYYY-MM-DD HH:MM:SS UTC' YYYYMMDD_HHMMSS"
    exit 1
fi

echo "Starting PITR to: $TARGET_TIME using backup: $BACKUP_DATE"

# Create new cluster for PITR
sudo -u postgres pg_createcluster 14 pitr
sudo -u postgres rm -rf /var/lib/postgresql/14/pitr/*

# Download and extract base backup
aws s3 cp "s3://thrifts-db-backups/base/base_backup_$BACKUP_DATE.tar.gz" /tmp/
sudo -u postgres tar -xzf /tmp/base_backup_$BACKUP_DATE.tar.gz -C /var/lib/postgresql/14/pitr/

# Configure recovery
sudo -u postgres cat > /var/lib/postgresql/14/pitr/postgresql.auto.conf << EOF
port = 5433
restore_command = 'aws s3 cp s3://thrifts-db-backups/wal/%f %p'
recovery_target_time = '$TARGET_TIME'
recovery_target_action = 'promote'
EOF

# Start PITR instance
sudo systemctl start postgresql@14-pitr

# Wait for recovery completion
echo "Waiting for recovery to complete..."
while sudo -u postgres psql -p 5433 -c "SELECT pg_is_in_recovery();" | grep -q "t"; do
    sleep 5
    echo "Still recovering..."
done

echo "PITR completed successfully!"
echo "Verify data and switch applications to port 5433"
echo "To make permanent: stop main instance and change ports"
```

### 2.3 Online Backup Verification

```bash
#!/bin/bash
# verify_backup.sh - Monthly backup verification

BACKUP_DATE=$(date -d "yesterday" +%Y%m%d)
VERIFY_PORT=5434

# Create verification cluster
sudo -u postgres pg_createcluster 14 verify
sudo -u postgres rm -rf /var/lib/postgresql/14/verify/*

# Restore latest backup for verification
aws s3 cp "s3://thrifts-db-backups/base/base_backup_${BACKUP_DATE}_020000.tar.gz" /tmp/
sudo -u postgres tar -xzf /tmp/base_backup_${BACKUP_DATE}_020000.tar.gz -C /var/lib/postgresql/14/verify/

# Configure verification instance
sudo -u postgres sed -i "s/port = 5432/port = $VERIFY_PORT/" /var/lib/postgresql/14/verify/postgresql.conf

# Start and test
sudo systemctl start postgresql@14-verify

# Run smoke tests
sudo -u postgres psql -p $VERIFY_PORT -d thrifts_production << EOF
-- Basic connectivity
SELECT version();

-- Check table counts
SELECT 
  'feeds' as table_name, count(*) as row_count 
FROM feeds
UNION ALL
SELECT 
  'events' as table_name, count(*) as row_count 
FROM events
UNION ALL
SELECT 
  'products' as table_name, count(*) as row_count 
FROM products;

-- Check recent data
SELECT 
  DATE(created_at) as date,
  count(*) as feed_count
FROM feeds 
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date;
EOF

# Cleanup verification instance
sudo systemctl stop postgresql@14-verify
sudo -u postgres pg_dropcluster 14 verify

echo "Backup verification completed successfully"
```

## 3. Recovery Testing Schedule

### 3.1 Monthly Full Restore Test

```bash
# First Monday of each month at 1 AM
0 1 1-7 * 1 root /opt/thrifts/scripts/verify_backup.sh >> /var/log/backup_verification.log 2>&1
```

### 3.2 Quarterly DR Drill

1. **Week 1**: Announce planned DR test
2. **Week 2**: Execute full restore to temporary environment
3. **Week 3**: Validate application functionality on restored data
4. **Week 4**: Document lessons learned and update procedures

## 4. Monitoring & Alerts

### 4.1 Backup Monitoring

```sql
-- Check last successful backup
SELECT 
  pg_stat_file('backup_label'),
  pg_last_wal_replay_lsn(),
  pg_last_wal_receive_lsn();

-- Check WAL archiving status
SELECT 
  archived_count,
  last_archived_wal,
  last_archived_time,
  failed_count,
  last_failed_wal,
  last_failed_time
FROM pg_stat_archiver;
```

### 4.2 Alert Conditions

```yaml
# CloudWatch/monitoring alerts
alerts:
  - name: "Backup Failed"
    condition: "backup_script exit_code != 0"
    severity: "critical"
    
  - name: "WAL Archive Lag"
    condition: "wal_archive_age > 10 minutes"
    severity: "warning"
    
  - name: "Replication Lag High"
    condition: "replica_lag > 60 seconds"
    severity: "critical"
    
  - name: "Backup Verification Failed"
    condition: "backup_verification exit_code != 0"
    severity: "critical"
```

## 5. Emergency Contacts & Escalation

### 5.1 On-Call Procedures

1. **Database Issue Detected** → Page on-call engineer
2. **RTO > 15 minutes** → Escalate to senior DBA
3. **RTO > 30 minutes** → Notify engineering management
4. **Data Loss Suspected** → Immediate executive notification

### 5.2 Communication Template

```
Subject: [URGENT] Database Recovery in Progress - Thrifts Production

Status: [INVESTIGATING/IN_PROGRESS/RESOLVED]
Impact: [Brief description of user impact]
ETA: [Estimated resolution time]

Details:
- Issue: [What happened]
- Root Cause: [If known]
- Actions Taken: [Recovery steps]
- Next Steps: [Planned actions]

Point of Contact: [Engineer name + phone]
```

## 6. Security & Access

### 6.1 Backup Encryption

```bash
# S3 bucket policy for backup encryption
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::thrifts-db-backups/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    }
  ]
}
```

### 6.2 Access Controls

```bash
# IAM policy for backup access
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::thrifts-db-backups/*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::thrifts-db-backups"
    }
  ]
}
```

## 7. Post-Recovery Validation

### 7.1 Application Health Checks

```bash
#!/bin/bash
# post_recovery_validation.sh

DB_HOST="${1:-localhost}"
DB_PORT="${2:-5432}"

echo "Validating database connectivity..."
pg_isready -h $DB_HOST -p $DB_PORT

echo "Testing critical application paths..."

# Test feed generation
curl -X POST http://localhost:3000/api/feed/start \
  -H "Content-Type: application/json" \
  -d '{
    "page": "home",
    "session_id": "recovery_test",
    "region": "Nairobi"
  }'

# Test event ingestion
curl -X POST http://localhost:3000/api/events \
  -H "Content-Type: application/json" \
  -d '{
    "events": [{
      "event_id": "recovery_test_001",
      "session_id": "recovery_test",
      "event_name": "page_view",
      "page": "home",
      "region": "Nairobi",
      "payload": {}
    }]
  }'

echo "Validation completed"
```

### 7.2 Data Integrity Checks

```sql
-- Check for missing foreign key relationships
SELECT 'feed_items without feeds' as issue, count(*)
FROM feed_items fi
LEFT JOIN feeds f ON f.id = fi.feed_id
WHERE f.id IS NULL;

-- Check for recent data continuity
SELECT 
  DATE(created_at) as date,
  count(*) as events_count
FROM events
WHERE created_at >= CURRENT_DATE - INTERVAL '3 days'
GROUP BY DATE(created_at)
ORDER BY date;

-- Verify partitions are healthy
SELECT 
  schemaname,
  tablename,
  n_live_tup,
  n_dead_tup,
  last_vacuum,
  last_autovacuum
FROM pg_stat_user_tables
WHERE tablename LIKE 'events_%'
ORDER BY tablename;
```

## 8. Cost Optimization

### 8.1 Backup Retention

- **Base backups**: 30 days
- **WAL files**: 7 days  
- **Monthly verification backups**: 12 months
- **Yearly compliance backups**: 7 years (cold storage)

### 8.2 Storage Classes

```bash
# S3 lifecycle policy
{
  "Rules": [
    {
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        },
        {
          "Days": 365,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ]
    }
  ]
}
```

This runbook ensures reliable backup/restore capabilities with clear procedures, testing schedules, and monitoring to meet our RPO/RTO targets.
