#!/bin/bash

# Django Ticketing System - PostgreSQL Database Setup Script
# Phase 2: Database server configuration
# Run this script as root after system setup

set -e  # Exit on any error

echo "🐘 Django Ticketing System - PostgreSQL Setup"
echo "=============================================="
echo "Phase 2: Configuring PostgreSQL database server"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[CONFIG]${NC} $1"
}

# Database configuration
DB_NAME="django_ticketing_db"
DB_USER="django_ticketing_user"
DB_PASSWORD="$(openssl rand -base64 32 | tr -d '/' | cut -c1-20)SecureDB2024!"

print_status "Database Configuration:"
print_info "Database Name: $DB_NAME"
print_info "Database User: $DB_USER"
print_info "Database Password: $DB_PASSWORD"

# Start and enable PostgreSQL
print_status "Starting and enabling PostgreSQL service..."
systemctl start postgresql
systemctl enable postgresql

# Wait for PostgreSQL to be ready
print_status "Waiting for PostgreSQL to be ready..."
sleep 5

# Create database and user
print_status "Creating database and user..."
sudo -u postgres psql << EOF
-- Create database
CREATE DATABASE $DB_NAME;

-- Create user with password
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';

-- Set user permissions
ALTER ROLE $DB_USER SET client_encoding TO 'utf8';
ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';
ALTER ROLE $DB_USER SET timezone TO 'UTC';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;

-- Grant schema privileges
\c $DB_NAME
GRANT ALL ON SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;

-- Show databases
\l

-- Exit
\q
EOF

# Backup original PostgreSQL configuration
print_status "Backing up original PostgreSQL configuration..."
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP '\d+\.\d+' | head -1)
PG_MAIN_DIR="/etc/postgresql/$PG_VERSION/main"

if [ -d "$PG_MAIN_DIR" ]; then
    cp "$PG_MAIN_DIR/postgresql.conf" "$PG_MAIN_DIR/postgresql.conf.backup"
    cp "$PG_MAIN_DIR/pg_hba.conf" "$PG_MAIN_DIR/pg_hba.conf.backup"
else
    print_error "PostgreSQL configuration directory not found"
    exit 1
fi

# Configure PostgreSQL for production
print_status "Configuring PostgreSQL for production..."
cat >> "$PG_MAIN_DIR/postgresql.conf" << 'EOF'

# Django Ticketing System Production Configuration
# Added by deployment script

# Connection Settings
listen_addresses = 'localhost'
port = 5432
max_connections = 100

# Memory Settings
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
work_mem = 4MB

# Checkpoint Settings
checkpoint_completion_target = 0.9
wal_buffers = 16MB

# Query Planning
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_min_duration_statement = 1000
log_connections = on
log_disconnections = on
log_lock_waits = on

# Security
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
EOF

# Configure pg_hba.conf for security
print_status "Configuring PostgreSQL authentication..."
cat > "$PG_MAIN_DIR/pg_hba.conf" << 'EOF'
# PostgreSQL Client Authentication Configuration File
# Django Ticketing System Configuration

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             postgres                                peer
local   all             all                                     peer

# IPv4 local connections:
host    all             all             127.0.0.1/32            md5
host    django_ticketing_db    django_ticketing_user    127.0.0.1/32    md5

# IPv6 local connections:
host    all             all             ::1/128                 md5

# Deny all other connections
# Add specific IPs here if needed for remote access
EOF

# Create database backup script
print_status "Creating database backup script..."
mkdir -p /opt/django-ticketing/backups
cat > /opt/django-ticketing/backups/backup_database.sh << EOF
#!/bin/bash
# Database backup script for Django Ticketing System

BACKUP_DIR="/opt/django-ticketing/backups"
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="\$BACKUP_DIR/django_ticketing_db_\$DATE.sql"

# Create backup
sudo -u postgres pg_dump $DB_NAME > "\$BACKUP_FILE"

# Compress backup
gzip "\$BACKUP_FILE"

# Keep only last 30 days of backups
find "\$BACKUP_DIR" -name "django_ticketing_db_*.sql.gz" -mtime +30 -delete

echo "Database backup completed: \$BACKUP_FILE.gz"
EOF

chmod +x /opt/django-ticketing/backups/backup_database.sh
chown django-user:django-user /opt/django-ticketing/backups/backup_database.sh

# Set up daily backup cron job
print_status "Setting up daily database backups..."
cat > /etc/cron.d/django-ticketing-backup << 'EOF'
# Daily database backup for Django Ticketing System
0 2 * * * django-user /opt/django-ticketing/backups/backup_database.sh >> /opt/django-ticketing/logs/backup.log 2>&1
EOF

# Restart PostgreSQL with new configuration
print_status "Restarting PostgreSQL with new configuration..."
systemctl restart postgresql

# Wait for PostgreSQL to be ready
sleep 5

# Test database connection
print_status "Testing database connection..."
if sudo -u postgres psql -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
    print_status "✅ Database connection test successful"
else
    print_error "❌ Database connection test failed"
    exit 1
fi

# Save database credentials to file
print_status "Saving database credentials..."
cat > /opt/django-ticketing/.db_credentials << EOF
# Database credentials for Django Ticketing System
# Generated on $(date)

DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_HOST=localhost
DB_PORT=5432

# Connection URL format for Django
DATABASE_URL=postgres://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME
EOF

chmod 600 /opt/django-ticketing/.db_credentials
chown django-user:django-user /opt/django-ticketing/.db_credentials

print_status "✅ Phase 2 Complete: PostgreSQL database configured"
print_status "📋 Database Summary:"
echo "   - Database Name: $DB_NAME"
echo "   - Database User: $DB_USER"
echo "   - Database Password: $DB_PASSWORD"
echo "   - Connection: localhost:5432"
echo "   - Credentials saved: /opt/django-ticketing/.db_credentials"
echo "   - Daily backups configured"
echo "   - Security hardened"
echo ""
print_status "🔄 Next: Run 03-django-app-setup.sh to deploy the Django application"
