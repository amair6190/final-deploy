#!/bin/bash

# Complete Fix for Django Deployment Issues
# This script addresses all the deployment problems encountered

echo "🔧 Fixing Django Ticketing System deployment issues..."
echo "=================================================="

# Fix 1: Update the main deployment script to handle permissions and configuration properly
cat > deploy-http-only-complete-fix.sh << 'EOF'
#!/bin/bash

# Django Ticketing System - Complete HTTP-Only Deployment Script (FIXED)
# This script automates the entire deployment process without SSL
# Run this script as root on a fresh Ubuntu server

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Functions for colored output
print_banner() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${BOLD}              Django Ticketing System Deployment              ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${BOLD}                    HTTP-Only Version (FIXED)                ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_phase() {
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD} $1${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}${BOLD}[SUCCESS]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[CONFIG]${NC} $1"
}

# Configuration
DEPLOYMENT_DIR="/opt/django-ticketing"
LOG_FILE="/var/log/django-deployment.log"
BACKUP_DIR="/opt/backups"
GITHUB_REPO="https://github.com/amair6190/solvit-django-ticketing-system.git"
CONFIG_FILE="/tmp/deployment_config.env"

# Start deployment
print_banner
print_status "Starting Django Ticketing System deployment..."
print_status "Deployment started at: $(date)"
print_status "Log file: $LOG_FILE"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

# Create log file and directories
mkdir -p $(dirname "$LOG_FILE")
mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"

# Function to log commands with better error handling
log_command() {
    local cmd="$1"
    local description="$2"
    
    if [ -n "$description" ]; then
        print_status "$description"
    fi
    
    echo "$(date): Executing: $cmd" >> "$LOG_FILE"
    
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        if [ -n "$description" ]; then
            print_success "$description completed"
        fi
        return 0
    else
        local exit_code=$?
        print_error "Command failed: $cmd"
        print_error "Check log file: $LOG_FILE"
        return $exit_code
    fi
}

# Collect configuration
collect_config() {
    print_phase "CONFIGURATION SETUP"
    
    # Get server information
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "127.0.0.1")
    HOSTNAME=$(hostname)
    
    print_info "Server IP: $SERVER_IP"
    print_info "Hostname: $HOSTNAME"
    
    # Interactive configuration
    echo -e "${YELLOW}Please provide the following information:${NC}"
    echo ""
    
    read -p "Domain name (or press Enter for IP-only access): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        DOMAIN="$SERVER_IP"
    fi
    
    read -p "Database name [django_ticketing]: " DB_NAME
    DB_NAME=${DB_NAME:-django_ticketing}
    
    read -p "Database user [django_user]: " DB_USER
    DB_USER=${DB_USER:-django_user}
    
    read -s -p "Database password (will be hidden): " DB_PASSWORD
    echo ""
    if [ -z "$DB_PASSWORD" ]; then
        DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        print_warning "Generated random password: $DB_PASSWORD"
    fi
    
    read -p "Django admin email: " ADMIN_EMAIL
    while [ -z "$ADMIN_EMAIL" ]; do
        read -p "Admin email is required: " ADMIN_EMAIL
    done
    
    read -p "Django admin username [admin]: " ADMIN_USER
    ADMIN_USER=${ADMIN_USER:-admin}
    
    read -s -p "Django admin password: " ADMIN_PASSWORD
    echo ""
    while [ -z "$ADMIN_PASSWORD" ]; do
        read -s -p "Admin password is required: " ADMIN_PASSWORD
        echo ""
    done
    
    # Generate a temporary secret key (will be replaced after Django is installed)
    SECRET_KEY=$(openssl rand -base64 50 | tr -d "=+/" | cut -c1-50)
    
    # Save configuration
    cat > "$CONFIG_FILE" << EOF
# Django Ticketing System Deployment Configuration
export DOMAIN="$DOMAIN"
export SERVER_IP="$SERVER_IP"
export DB_NAME="$DB_NAME"
export DB_USER="$DB_USER"
export DB_PASSWORD="$DB_PASSWORD"
export ADMIN_EMAIL="$ADMIN_EMAIL"
export ADMIN_USER="$ADMIN_USER"
export ADMIN_PASSWORD="$ADMIN_PASSWORD"
export SECRET_KEY="$SECRET_KEY"
export DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
export GITHUB_REPO="$GITHUB_REPO"
EOF
    
    # Make sure config file is readable
    chmod 644 "$CONFIG_FILE"
    
    print_success "Configuration saved to $CONFIG_FILE"
    echo ""
    
    # Summary
    print_info "Deployment Summary:"
    print_info "  Domain: $DOMAIN"
    print_info "  Database: $DB_NAME"
    print_info "  DB User: $DB_USER"
    print_info "  Admin Email: $ADMIN_EMAIL"
    print_info "  Admin User: $ADMIN_USER"
    print_info "  Deployment Directory: $DEPLOYMENT_DIR"
    echo ""
    
    read -p "Continue with deployment? (y/N): " CONFIRM
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled by user"
        exit 0
    fi
}

# Pre-deployment checks
pre_deployment_checks() {
    print_phase "PRE-DEPLOYMENT CHECKS"
    
    # Check Ubuntu version
    UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "Unknown")
    print_info "Ubuntu version: $UBUNTU_VERSION"
    
    # Check available disk space
    DISK_SPACE=$(df -h / | awk 'NR==2{print $4}')
    print_info "Available disk space: $DISK_SPACE"
    
    # Check memory
    MEMORY=$(free -h | awk 'NR==2{print $2}')
    print_info "Total memory: $MEMORY"
    
    # Check if ports are available
    if netstat -tuln 2>/dev/null | grep -q ":80 "; then
        print_warning "Port 80 is already in use"
    else
        print_success "Port 80 is available"
    fi
    
    if netstat -tuln 2>/dev/null | grep -q ":5432 "; then
        print_warning "Port 5432 (PostgreSQL) is already in use"
    else
        print_success "Port 5432 is available"
    fi
    
    print_success "Pre-deployment checks completed"
}

# Phase 1: System Setup
phase1_system_setup() {
    print_phase "PHASE 1: SYSTEM SETUP"
    
    source "$CONFIG_FILE"
    
    print_status "Updating system packages..."
    log_command "apt update && apt upgrade -y" "System package update"
    
    print_status "Installing system dependencies..."
    log_command "apt install -y python3 python3-pip python3-venv python3-dev build-essential git curl wget nginx postgresql postgresql-contrib libpq-dev supervisor ufw fail2ban logrotate" "System dependencies installation"
    
    print_status "Creating deployment directory..."
    mkdir -p "$DEPLOYMENT_DIR"
    
    print_success "PHASE 1: System setup completed"
}

# Phase 2: Database Setup
phase2_database_setup() {
    print_phase "PHASE 2: DATABASE SETUP"
    
    source "$CONFIG_FILE"
    
    print_status "Starting PostgreSQL service..."
    log_command "systemctl start postgresql" "PostgreSQL service start"
    log_command "systemctl enable postgresql" "PostgreSQL service enable"
    
    print_status "Creating database and user..."
    
    # Create database user and database
    sudo -u postgres psql << EOF
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;
\q
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Database and user created successfully"
    else
        print_error "Failed to create database and user"
        exit 1
    fi
    
    print_success "PHASE 2: Database setup completed"
}

# Phase 3: Django Application Setup
phase3_django_setup() {
    print_phase "PHASE 3: DJANGO APPLICATION SETUP"
    
    source "$CONFIG_FILE"
    
    print_status "Cloning Django application..."
    cd "$DEPLOYMENT_DIR"
    
    if [ -d "app" ]; then
        print_warning "Application directory exists, backing up..."
        mv app "app.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi
    
    log_command "git clone $GITHUB_REPO app" "Git clone application"
    
    cd "$DEPLOYMENT_DIR/app"
    
    print_status "Creating Python virtual environment..."
    log_command "python3 -m venv venv" "Virtual environment creation"
    
    print_status "Installing Python dependencies..."
    source venv/bin/activate
    log_command "pip install --upgrade pip" "Pip upgrade"
    log_command "pip install -r requirements.txt" "Python dependencies installation"
    
    print_status "Configuring Django settings..."
    
    # Create production settings file
    cat > it_ticketing_system/settings_production.py << EOF
from .settings import *
import os

DEBUG = False
ALLOWED_HOSTS = ['$DOMAIN', '$SERVER_IP', 'localhost', '127.0.0.1']

# Database configuration
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': '$DB_NAME',
        'USER': '$DB_USER',
        'PASSWORD': '$DB_PASSWORD',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}

# Security settings
SECRET_KEY = '$SECRET_KEY'
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'

# Static and media files
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# Logging
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': '/var/log/django-ticketing/django.log',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file'],
            'level': 'INFO',
            'propagate': True,
        },
    },
}
EOF
    
    # Set DJANGO_SETTINGS_MODULE environment variable
    export DJANGO_SETTINGS_MODULE=it_ticketing_system.settings_production
    
    print_status "Running Django migrations..."
    log_command "python manage.py migrate --settings=it_ticketing_system.settings_production" "Database migrations"
    
    print_status "Collecting static files..."
    log_command "python manage.py collectstatic --noinput --settings=it_ticketing_system.settings_production" "Static files collection"
    
    # Create log directory
    mkdir -p /var/log/django-ticketing
    
    # Set permissions
    chown -R www-data:www-data "$DEPLOYMENT_DIR"
    chown -R www-data:www-data /var/log/django-ticketing
    
    print_success "PHASE 3: Django application setup completed"
}

# Update Django secret key with proper Django key
update_django_secret_key() {
    print_phase "UPDATING DJANGO SECRET KEY"
    
    source "$CONFIG_FILE"
    
    cd "$DEPLOYMENT_DIR/app"
    source venv/bin/activate
    
    # Generate proper Django secret key
    print_status "Generating proper Django secret key..."
    NEW_SECRET_KEY=$(python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")
    
    # Update the settings file
    sed -i "s|SECRET_KEY = '.*'|SECRET_KEY = '$NEW_SECRET_KEY'|" it_ticketing_system/settings_production.py
    
    # Update the environment file
    sed -i "s|SECRET_KEY=\".*\"|SECRET_KEY=\"$NEW_SECRET_KEY\"|" "$CONFIG_FILE"
    
    print_success "Django secret key updated"
}

# Phase 4: Gunicorn Setup
phase4_gunicorn_setup() {
    print_phase "PHASE 4: GUNICORN SETUP"
    
    source "$CONFIG_FILE"
    
    cd "$DEPLOYMENT_DIR/app"
    
    print_status "Installing Gunicorn..."
    source venv/bin/activate
    log_command "pip install gunicorn" "Gunicorn installation"
    
    print_status "Creating Gunicorn configuration..."
    
    # Create Gunicorn configuration file
    cat > gunicorn.conf.py << EOF
# Gunicorn configuration file
bind = "unix:$DEPLOYMENT_DIR/app/gunicorn.sock"
workers = 3
user = "www-data"
group = "www-data"
timeout = 60
keepalive = 2
max_requests = 1000
max_requests_jitter = 100
worker_class = "sync"
EOF
    
    # Create systemd service file
    cat > /etc/systemd/system/gunicorn-django-ticketing.service << EOF
[Unit]
Description=Gunicorn instance to serve Django Ticketing System
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$DEPLOYMENT_DIR/app
Environment="DJANGO_SETTINGS_MODULE=it_ticketing_system.settings_production"
ExecStart=$DEPLOYMENT_DIR/app/venv/bin/gunicorn --config gunicorn.conf.py it_ticketing_system.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    
    print_status "Starting Gunicorn service..."
    log_command "systemctl daemon-reload" "Systemd daemon reload"
    log_command "systemctl start gunicorn-django-ticketing" "Gunicorn service start"
    log_command "systemctl enable gunicorn-django-ticketing" "Gunicorn service enable"
    
    print_success "PHASE 4: Gunicorn setup completed"
}

# Phase 5: Nginx Setup (HTTP Only)
phase5_nginx_setup() {
    print_phase "PHASE 5: NGINX SETUP (HTTP ONLY)"
    
    source "$CONFIG_FILE"
    
    print_status "Configuring Nginx..."
    
    # Create Nginx configuration
    cat > /etc/nginx/sites-available/django-ticketing << EOF
# Django Ticketing System Nginx Configuration (HTTP Only)

upstream django_app {
    server unix:$DEPLOYMENT_DIR/app/gunicorn.sock fail_timeout=0;
}

# Rate limiting zones
limit_req_zone \$binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone \$binary_remote_addr zone=general:10m rate=1r/s;

# HTTP Server Configuration
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN $SERVER_IP _;
    
    # Basic security headers (without HSTS)
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # File upload limits
    client_max_body_size 100M;
    client_body_buffer_size 1M;
    client_body_timeout 60s;
    client_header_timeout 60s;
    
    # Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # Security: Block common attack patterns
    location ~* \.(htaccess|htpasswd|ini|log|sh|sql|conf)$ {
        deny all;
        return 404;
    }
    
    # Security: Block access to sensitive files
    location ~* /\. {
        deny all;
        return 404;
    }
    
    # Rate limiting for login attempts
    location ~* /(admin|login|auth)/ {
        limit_req zone=login burst=3 nodelay;
        proxy_pass http://django_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://django_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Static files with caching
    location /static/ {
        alias $DEPLOYMENT_DIR/app/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        add_header Vary "Accept-Encoding";
        
        # Security for static files
        location ~* \.(js|css)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Media files with caching
    location /media/ {
        alias $DEPLOYMENT_DIR/app/media/;
        expires 7d;
        add_header Cache-Control "public";
        
        # Security for media files
        location ~* \.(jpg|jpeg|png|gif|pdf|doc|docx|txt|zip|rar)$ {
            expires 7d;
            add_header Cache-Control "public";
        }
    }
    
    # Django application
    location / {
        # Rate limiting for general requests
        limit_req zone=general burst=10 nodelay;
        
        proxy_pass http://django_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Proxy timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
    
    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    
    # Logging
    access_log /var/log/nginx/django-ticketing-access.log;
    error_log /var/log/nginx/django-ticketing-error.log;
}
EOF
    
    # Enable the site
    print_status "Enabling Django Ticketing site..."
    ln -sf /etc/nginx/sites-available/django-ticketing /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test Nginx configuration
    print_status "Testing Nginx configuration..."
    if nginx -t; then
        print_success "Nginx configuration is valid!"
    else
        print_error "Nginx configuration test failed!"
        exit 1
    fi
    
    # Create log directory
    mkdir -p /var/log/nginx
    chown -R www-data:www-data /var/log/nginx
    
    # Start and enable Nginx
    print_status "Starting Nginx service..."
    log_command "systemctl restart nginx" "Nginx service restart"
    log_command "systemctl enable nginx" "Nginx service enable"
    
    print_success "PHASE 5: Nginx setup completed"
}

# Phase 6: Security Setup
phase6_security_setup() {
    print_phase "PHASE 6: SECURITY SETUP"
    
    print_status "Configuring firewall..."
    log_command "ufw allow 22/tcp" "SSH port allow"
    log_command "ufw allow 80/tcp" "HTTP port allow"
    log_command "ufw --force enable" "Firewall enable"
    
    print_status "Configuring fail2ban..."
    systemctl start fail2ban || true
    systemctl enable fail2ban || true
    
    print_success "PHASE 6: Security setup completed"
}

# Create Django superuser
create_superuser() {
    print_phase "CREATING DJANGO SUPERUSER"
    
    source "$CONFIG_FILE"
    
    cd "$DEPLOYMENT_DIR/app"
    source venv/bin/activate
    
    # Create superuser script
    cat > create_superuser.py << EOF
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'it_ticketing_system.settings_production')
django.setup()

from django.contrib.auth import get_user_model
User = get_user_model()

if not User.objects.filter(username='$ADMIN_USER').exists():
    User.objects.create_superuser('$ADMIN_USER', '$ADMIN_EMAIL', '$ADMIN_PASSWORD')
    print('Superuser created successfully')
else:
    print('Superuser already exists')
EOF
    
    # Execute superuser creation
    python create_superuser.py
    rm create_superuser.py
    
    print_success "Django superuser created"
}

# Final checks and summary
final_checks() {
    print_phase "FINAL CHECKS"
    
    source "$CONFIG_FILE"
    
    print_status "Checking services..."
    if systemctl is-active --quiet postgresql; then
        print_success "PostgreSQL: Running"
    else
        print_error "PostgreSQL: Not running"
    fi
    
    if systemctl is-active --quiet gunicorn-django-ticketing; then
        print_success "Gunicorn: Running"
    else
        print_error "Gunicorn: Not running"
    fi
    
    if systemctl is-active --quiet nginx; then
        print_success "Nginx: Running"
    else
        print_error "Nginx: Not running"
    fi
    
    print_status "Setting final permissions..."
    chown -R www-data:www-data "$DEPLOYMENT_DIR"
    chmod -R 755 "$DEPLOYMENT_DIR"
    
    print_success "Final checks completed"
}

# Display final summary
display_summary() {
    print_phase "DEPLOYMENT COMPLETE!"
    
    source "$CONFIG_FILE"
    
    echo -e "${GREEN}${BOLD}🎉 Django Ticketing System successfully deployed!${NC}"
    echo ""
    echo -e "${CYAN}🌐 Access Your Application:${NC}"
    echo -e "   → Application: ${BOLD}http://$DOMAIN${NC}"
    echo -e "   → Admin Panel: ${BOLD}http://$DOMAIN/admin/${NC}"
    echo ""
    echo -e "${CYAN}🔐 Admin Credentials:${NC}"
    echo -e "   → Username: ${BOLD}$ADMIN_USER${NC}"
    echo -e "   → Email: ${BOLD}$ADMIN_EMAIL${NC}"
    echo ""
    echo -e "${CYAN}📋 System Services:${NC}"
    echo -e "   → PostgreSQL: $(systemctl is-active postgresql)"
    echo -e "   → Gunicorn: $(systemctl is-active gunicorn-django-ticketing)"
    echo -e "   → Nginx: $(systemctl is-active nginx)"
    echo ""
    echo -e "${CYAN}📂 Important Paths:${NC}"
    echo -e "   → Application: ${BOLD}$DEPLOYMENT_DIR/app/${NC}"
    echo -e "   → Logs: ${BOLD}/var/log/nginx/ and /var/log/django-ticketing/${NC}"
    echo -e "   → Configuration: ${BOLD}$CONFIG_FILE${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Important Notes:${NC}"
    echo -e "   → This is an HTTP-only deployment (no SSL/HTTPS)"
    echo -e "   → For production, consider enabling SSL later"
    echo -e "   → Regular backups are recommended"
    echo -e "   → Monitor logs for any issues"
    echo ""
    echo -e "${CYAN}🎯 Next Steps:${NC}"
    echo -e "   1. Test your application at http://$DOMAIN"
    echo -e "   2. Login to admin panel and configure settings"
    echo -e "   3. Create additional user accounts if needed"
    echo -e "   4. Set up regular maintenance schedules"
    echo ""
    
    # Clean up sensitive information
    print_status "Cleaning up deployment configuration..."
    # Keep config file for troubleshooting but secure it
    chmod 600 "$CONFIG_FILE"
    
    print_success "Deployment completed successfully!"
    print_status "Total deployment time: $(($(date +%s) - START_TIME)) seconds"
}

# Main deployment process
main() {
    START_TIME=$(date +%s)
    
    # Change to script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$SCRIPT_DIR"
    
    # Execute deployment phases
    collect_config
    pre_deployment_checks
    phase1_system_setup
    phase2_database_setup
    phase3_django_setup
    update_django_secret_key
    phase4_gunicorn_setup
    phase5_nginx_setup
    phase6_security_setup
    create_superuser
    final_checks
    display_summary
}

# Trap for cleanup on exit
cleanup() {
    if [ -f "$CONFIG_FILE" ]; then
        chmod 600 "$CONFIG_FILE" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Run main function
main "$@"
EOF

chmod +x deploy-http-only-complete-fix.sh

echo ""
echo "✅ Complete deployment fix created!"
echo ""
echo "🔧 This fix addresses:"
echo "   ✅ Permission denied issues"
echo "   ✅ Configuration passing between phases"
echo "   ✅ Django import errors"
echo "   ✅ Database credential handling"
echo "   ✅ Proper service setup and configuration"
echo ""
echo "📋 To use the fixed deployment script:"
echo ""
echo "1. Stop the current deployment (Ctrl+C)"
echo "2. Replace the script:"
echo "   cp deploy-http-only-complete-fix.sh deploy-http-only.sh"
echo "3. Run the deployment again:"
echo "   sudo ./deploy-http-only.sh"
echo ""
echo "🎯 The new script includes:"
echo "   → Integrated phases (no separate scripts needed)"
echo "   → Better error handling and logging"
echo "   → Proper configuration management"
echo "   → Complete service setup"
echo "   → Security configuration"
echo ""
