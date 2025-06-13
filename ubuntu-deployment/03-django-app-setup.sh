#!/bin/bash

# Django Ticketing System - Application Deployment Script
# Phase 3: Django application setup and configuration
# Run this script as root after database setup

set -e  # Exit on any error

echo "🐍 Django Ticketing System - Application Setup"
echo "=============================================="
echo "Phase 3: Deploying and configuring Django application"

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

# Configuration variables
APP_DIR="/opt/django-ticketing/app"
REPO_URL="https://github.com/amair6190/solvit-django-ticketing-system.git"
DOMAIN="your-domain.com"  # Change this to your actual domain
SERVER_IP="your-server-ip"  # Change this to your server IP

# Load database credentials
if [ -f "/opt/django-ticketing/.db_credentials" ]; then
    source /opt/django-ticketing/.db_credentials
    print_status "Database credentials loaded"
else
    print_error "Database credentials not found. Run 02-postgresql-setup.sh first"
    exit 1
fi

# Clone or update repository
print_status "Setting up application repository..."
if [ -d "$APP_DIR" ]; then
    print_warning "Application directory exists. Updating..."
    cd "$APP_DIR"
    sudo -u django-user git pull origin main
else
    print_status "Cloning repository..."
    sudo -u django-user git clone "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"
chown -R django-user:django-user "$APP_DIR"

# Create virtual environment
print_status "Creating Python virtual environment..."
if [ ! -d "venv" ]; then
    sudo -u django-user python3 -m venv venv
fi

# Upgrade pip and install requirements
print_status "Installing Python dependencies..."
sudo -u django-user ./venv/bin/pip install --upgrade pip setuptools wheel
sudo -u django-user ./venv/bin/pip install -r requirements.txt

# Generate secure secret key
SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')

# Create production environment file
print_status "Creating production environment configuration..."
cat > .env << EOF
# Django Ticketing System - Production Environment Configuration
# Generated on $(date)

# Django Core Settings
DEBUG=False
SECRET_KEY=$SECRET_KEY
ALLOWED_HOSTS=$DOMAIN,www.$DOMAIN,$SERVER_IP,localhost,127.0.0.1

# Database Configuration
DATABASE_URL=$DATABASE_URL
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT

# Email Configuration (Update with your SMTP settings)
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
DEFAULT_FROM_EMAIL=SolvIT Support <noreply@$DOMAIN>

# Redis Configuration
REDIS_URL=redis://localhost:6379/0

# Security Settings
SECURE_SSL_REDIRECT=True
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True
SECURE_BROWSER_XSS_FILTER=True
SECURE_CONTENT_TYPE_NOSNIFF=True
SECURE_HSTS_SECONDS=31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS=True
SECURE_HSTS_PRELOAD=True
X_FRAME_OPTIONS=DENY

# Admin Configuration
ADMIN_URL=secure-admin-$(openssl rand -hex 8)/
ADMIN_ALLOWED_IPS=127.0.0.1,$SERVER_IP

# File Upload Settings
FILE_UPLOAD_MAX_MEMORY_SIZE=5242880
DATA_UPLOAD_MAX_MEMORY_SIZE=5242880

# Logging
LOG_LEVEL=INFO
LOG_DIR=/opt/django-ticketing/logs

# Time Zone
TIME_ZONE=UTC
USE_TZ=True
EOF

chown django-user:django-user .env
chmod 600 .env

# Create additional required directories
print_status "Creating application directories..."
sudo -u django-user mkdir -p {media,static,logs}
sudo -u django-user mkdir -p media/{ticket_attachments,message_attachments,profile_pictures}

# Set proper permissions
chmod 755 media static
chmod 775 media/ticket_attachments media/message_attachments media/profile_pictures

# Create log files
touch logs/{django.log,gunicorn.log,celery.log,security.log}
chown django-user:django-user logs/*.log
chmod 644 logs/*.log

# Run Django management commands
print_status "Running Django migrations..."
sudo -u django-user ./venv/bin/python manage.py migrate --settings=it_ticketing_system.settings_production

print_status "Collecting static files..."
sudo -u django-user ./venv/bin/python manage.py collectstatic --noinput --settings=it_ticketing_system.settings_production

# Create default groups
print_status "Creating default user groups..."
sudo -u django-user ./venv/bin/python manage.py shell --settings=it_ticketing_system.settings_production << 'EOF'
from django.contrib.auth.models import Group

# Create groups if they don't exist
groups = ['Agents', 'Customers', 'Managers']
for group_name in groups:
    group, created = Group.objects.get_or_create(name=group_name)
    if created:
        print(f"Created group: {group_name}")
    else:
        print(f"Group already exists: {group_name}")
EOF

# Create superuser (interactive)
print_status "Creating Django superuser..."
echo ""
echo "🔑 You will now create a superuser account for Django admin access."
echo "    This account will have full administrative privileges."
echo ""
sudo -u django-user ./venv/bin/python manage.py createsuperuser --settings=it_ticketing_system.settings_production

# Create systemd service files
print_status "Creating systemd service files..."

# Django application service
cat > /etc/systemd/system/django-ticketing.service << 'EOF'
[Unit]
Description=Django Ticketing System Gunicorn Application Server
Requires=postgresql.service
After=network.target postgresql.service

[Service]
User=django-user
Group=django-user
WorkingDirectory=/opt/django-ticketing/app
Environment="PATH=/opt/django-ticketing/app/venv/bin"
Environment="DJANGO_SETTINGS_MODULE=it_ticketing_system.settings_production"
ExecStart=/opt/django-ticketing/app/venv/bin/gunicorn \
    --workers 3 \
    --bind unix:/opt/django-ticketing/app/gunicorn.sock \
    --timeout 60 \
    --keepalive 2 \
    --max-requests 1000 \
    --max-requests-jitter 100 \
    --preload \
    --access-logfile /opt/django-ticketing/logs/gunicorn_access.log \
    --error-logfile /opt/django-ticketing/logs/gunicorn_error.log \
    --log-level info \
    it_ticketing_system.wsgi:application
ExecReload=/bin/kill -s HUP $MAINPID
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable django-ticketing.service

# Create maintenance scripts
print_status "Creating maintenance scripts..."

# Deployment update script
cat > /opt/django-ticketing/update_app.sh << 'EOF'
#!/bin/bash
# Django Ticketing System Update Script

APP_DIR="/opt/django-ticketing/app"
cd "$APP_DIR"

echo "🔄 Updating Django Ticketing System..."

# Pull latest code
echo "📥 Pulling latest code..."
sudo -u django-user git pull origin main

# Install/update dependencies
echo "📦 Updating dependencies..."
sudo -u django-user ./venv/bin/pip install -r requirements.txt

# Run migrations
echo "🔄 Running database migrations..."
sudo -u django-user ./venv/bin/python manage.py migrate --settings=it_ticketing_system.settings_production

# Collect static files
echo "📦 Collecting static files..."
sudo -u django-user ./venv/bin/python manage.py collectstatic --noinput --settings=it_ticketing_system.settings_production

# Restart services
echo "🔄 Restarting services..."
systemctl restart django-ticketing
systemctl reload nginx

echo "✅ Update completed successfully!"
EOF

chmod +x /opt/django-ticketing/update_app.sh

# Create health check script
cat > /opt/django-ticketing/health_check.sh << 'EOF'
#!/bin/bash
# Django Ticketing System Health Check Script

echo "🏥 Django Ticketing System Health Check"
echo "======================================"

# Check Django service
if systemctl is-active --quiet django-ticketing; then
    echo "✅ Django service: Running"
else
    echo "❌ Django service: Not running"
fi

# Check PostgreSQL
if systemctl is-active --quiet postgresql; then
    echo "✅ PostgreSQL: Running"
else
    echo "❌ PostgreSQL: Not running"
fi

# Check Nginx
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx: Running"
else
    echo "❌ Nginx: Not running"
fi

# Check Redis
if systemctl is-active --quiet redis-server; then
    echo "✅ Redis: Running"
else
    echo "❌ Redis: Not running"
fi

# Check disk space
DISK_USAGE=$(df -h /opt/django-ticketing | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo "✅ Disk space: ${DISK_USAGE}% used"
else
    echo "⚠️ Disk space: ${DISK_USAGE}% used (Warning: >80%)"
fi

# Check application URL
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|301\|302"; then
    echo "✅ Application: Responding"
else
    echo "❌ Application: Not responding"
fi

echo ""
echo "📋 Quick Stats:"
echo "   - Active connections: $(ss -tuln | grep :80 | wc -l)"
echo "   - Memory usage: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
echo "   - Load average: $(uptime | awk -F'load average:' '{ print $2 }')"
EOF

chmod +x /opt/django-ticketing/health_check.sh

# Set ownership
chown -R django-user:django-user /opt/django-ticketing

print_status "✅ Phase 3 Complete: Django application deployed and configured"
print_status "📋 Application Summary:"
echo "   - Repository: $REPO_URL"
echo "   - Application Path: $APP_DIR"
echo "   - Virtual Environment: $APP_DIR/venv"
echo "   - Environment File: $APP_DIR/.env"
echo "   - Log Directory: /opt/django-ticketing/logs"
echo "   - Service: django-ticketing.service"
echo "   - Update Script: /opt/django-ticketing/update_app.sh"
echo "   - Health Check: /opt/django-ticketing/health_check.sh"
echo ""
print_status "🔄 Next: Run 04-nginx-setup.sh to configure the web server"
