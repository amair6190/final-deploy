#!/bin/bash

# Django Ticketing System - Complete Deployment with Your Database Config
# Database: solvit_ticketing_db
# User: amair
# Password: Ticket@solvit@2025

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
    echo -e "${CYAN}║${BOLD}              Solvit Django Ticketing System                  ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${BOLD}                Complete Manual Deployment                    ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_phase() {
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD} $1${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
DB_ENGINE="django.db.backends.postgresql"
DB_NAME="solvit_ticketing_db"
DB_USER="amair"
DB_PASSWORD="Ticket@solvit@2025"
DB_HOST="localhost"
DB_PORT="5432"
DEPLOYMENT_DIR="/opt/django_ticketing"
GITHUB_REPO="https://github.com/amair6190/solvit-django-ticketing-system.git"

print_banner

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "127.0.0.1")
print_info "Server IP detected: $SERVER_IP"

read -p "Enter your domain name (or press Enter to use $SERVER_IP): " DOMAIN
DOMAIN=${DOMAIN:-$SERVER_IP}

print_info "Domain/IP: $DOMAIN"
echo ""

read -p "Continue with deployment? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled by user"
    exit 0
fi

# Step 1: System Setup
print_phase "SYSTEM SETUP"
print_info "Updating system packages..."
apt update && apt upgrade -y

print_info "Installing essential packages..."
apt install -y curl wget git vim nano htop ufw fail2ban
apt install -y build-essential python3-dev libpq-dev python3-pip python3-venv
apt install -y lsb-release gnupg2 software-properties-common

print_success "System setup completed"
echo ""

# Step 2: PostgreSQL Setup
print_phase "POSTGRESQL SETUP"
print_info "Installing PostgreSQL..."
apt install -y postgresql postgresql-contrib

print_info "Starting PostgreSQL service..."
systemctl start postgresql
systemctl enable postgresql

print_info "Creating database and user..."
sudo -u postgres psql << EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
ALTER ROLE $DB_USER SET client_encoding TO 'utf8';
ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';
ALTER ROLE $DB_USER SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;
\q
EOF

print_success "PostgreSQL setup completed"
print_info "Database: $DB_NAME"
print_info "User: $DB_USER"
print_info "Password: $DB_PASSWORD"
echo ""

# Step 3: Django Application Setup
print_phase "DJANGO APPLICATION SETUP"
print_info "Creating deployment directory..."
mkdir -p $DEPLOYMENT_DIR
cd $DEPLOYMENT_DIR

print_info "Cloning repository..."
if [ -d ".git" ]; then
    print_info "Repository exists, updating..."
    git pull origin main
else
    git clone $GITHUB_REPO .
fi

print_info "Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

print_info "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements_core.txt
pip install gunicorn psycopg2-binary

print_success "Django application setup completed"
echo ""

# Step 4: Django Configuration
print_phase "DJANGO CONFIGURATION"
print_info "Generating Django secret key..."
SECRET_KEY=$(python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")

print_info "Creating production settings..."
cat > it_ticketing_system/settings_production.py << EOF
from .settings import *
import os

# Production settings
DEBUG = False
ALLOWED_HOSTS = ['$DOMAIN', '$SERVER_IP', 'localhost', '127.0.0.1']

# Database configuration
DATABASES = {
    'default': {
        'ENGINE': '$DB_ENGINE',
        'NAME': '$DB_NAME',
        'USER': '$DB_USER',
        'PASSWORD': '$DB_PASSWORD',
        'HOST': '$DB_HOST',
        'PORT': '$DB_PORT',
    }
}

# Security settings
SECRET_KEY = '$SECRET_KEY'
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'
SECURE_REFERRER_POLICY = 'strict-origin-when-cross-origin'

# Static and media files
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# File upload settings
FILE_UPLOAD_MAX_MEMORY_SIZE = 5242880  # 5MB
DATA_UPLOAD_MAX_MEMORY_SIZE = 5242880  # 5MB

# Email configuration
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

# Logging
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': '/var/log/django_app.log',
        },
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file', 'console'],
            'level': 'INFO',
            'propagate': True,
        },
    },
}
EOF

print_info "Setting Django environment..."
export DJANGO_SETTINGS_MODULE=it_ticketing_system.settings_production

print_info "Collecting static files..."
python manage.py collectstatic --noinput

print_info "Running database migrations..."
python manage.py migrate

print_info "Creating superuser..."
echo "You'll need to create an admin user. Please provide the following details:"
python manage.py createsuperuser

deactivate

print_success "Django configuration completed"
echo ""

# Step 5: Gunicorn Service Setup
print_phase "GUNICORN SERVICE SETUP"
print_info "Creating Gunicorn service file..."
cat > /etc/systemd/system/solvit_ticketing.service << EOF
[Unit]
Description=Solvit Django Ticketing System
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$DEPLOYMENT_DIR
Environment="DJANGO_SETTINGS_MODULE=it_ticketing_system.settings_production"
ExecStart=$DEPLOYMENT_DIR/venv/bin/gunicorn --access-logfile - --workers 3 --bind unix:$DEPLOYMENT_DIR/solvit_ticketing.sock it_ticketing_system.wsgi:application
Restart=always

[Install]
WantedBy=multi-user.target
EOF

print_info "Setting file permissions..."
chown -R www-data:www-data $DEPLOYMENT_DIR
chmod -R 755 $DEPLOYMENT_DIR

print_info "Starting Gunicorn service..."
systemctl daemon-reload
systemctl start solvit_ticketing
systemctl enable solvit_ticketing

print_success "Gunicorn service setup completed"
echo ""

# Step 6: Nginx Setup
print_phase "NGINX SETUP"
print_info "Installing Nginx..."
apt install -y nginx

print_info "Creating Nginx configuration..."
cat > /etc/nginx/sites-available/solvit_ticketing << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    client_max_body_size 20M;
    
    location = /favicon.ico { 
        access_log off; 
        log_not_found off; 
    }
    
    location /static/ {
        root $DEPLOYMENT_DIR;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        root $DEPLOYMENT_DIR;
        expires 7d;
        add_header Cache-Control "public";
    }
    
    location / {
        include proxy_params;
        proxy_pass http://unix:$DEPLOYMENT_DIR/solvit_ticketing.sock;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
    }
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
}
EOF

print_info "Enabling Nginx site..."
ln -sf /etc/nginx/sites-available/solvit_ticketing /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

print_info "Testing Nginx configuration..."
nginx -t

print_info "Starting Nginx..."
systemctl restart nginx
systemctl enable nginx

print_success "Nginx setup completed"
echo ""

# Step 7: Firewall Setup
print_phase "FIREWALL SETUP"
print_info "Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

print_success "Firewall setup completed"
echo ""

# Step 8: Final Verification
print_phase "DEPLOYMENT VERIFICATION"
print_info "Checking services..."

if systemctl is-active --quiet postgresql; then
    print_success "PostgreSQL is running"
else
    print_error "PostgreSQL is not running"
fi

if systemctl is-active --quiet solvit_ticketing; then
    print_success "Solvit Ticketing service is running"
else
    print_error "Solvit Ticketing service is not running"
fi

if systemctl is-active --quiet nginx; then
    print_success "Nginx is running"
else
    print_error "Nginx is not running"
fi

if [ -S "$DEPLOYMENT_DIR/solvit_ticketing.sock" ]; then
    print_success "Gunicorn socket file exists"
else
    print_error "Gunicorn socket file missing"
fi

print_success "Deployment verification completed"
echo ""

# Final Summary
print_phase "DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo ""
print_success "Your Solvit Django Ticketing System is now deployed!"
echo ""
print_info "Access your application at:"
print_info "  URL: http://$DOMAIN"
print_info "  Admin URL: http://$DOMAIN/admin/"
echo ""
print_info "Database Configuration:"
print_info "  Engine: $DB_ENGINE"
print_info "  Database: $DB_NAME"
print_info "  User: $DB_USER"
print_info "  Host: $DB_HOST:$DB_PORT"
echo ""
print_info "System Information:"
print_info "  Deployment Directory: $DEPLOYMENT_DIR"
print_info "  Service Name: solvit_ticketing"
print_info "  Log File: /var/log/django_app.log"
echo ""
print_warning "IMPORTANT NOTES:"
print_warning "1. Save your database credentials securely"
print_warning "2. Your Django secret key has been generated automatically"
print_warning "3. Consider setting up SSL/HTTPS for production use"
print_warning "4. Monitor application logs for any issues"
echo ""

# Create deployment summary
cat > $DEPLOYMENT_DIR/deployment_summary.txt << EOF
Solvit Django Ticketing System Deployment Summary
================================================
Date: $(date)
Domain: $DOMAIN
Server IP: $SERVER_IP

Database Configuration:
- Engine: $DB_ENGINE
- Database: $DB_NAME
- User: $DB_USER
- Password: $DB_PASSWORD
- Host: $DB_HOST:$DB_PORT

Application URLs:
- Main Application: http://$DOMAIN
- Admin Panel: http://$DOMAIN/admin/

System Configuration:
- Deployment Directory: $DEPLOYMENT_DIR
- Service Name: solvit_ticketing
- Virtual Environment: $DEPLOYMENT_DIR/venv
- Static Files: $DEPLOYMENT_DIR/staticfiles
- Media Files: $DEPLOYMENT_DIR/media
- Log File: /var/log/django_app.log

Nginx Configuration: /etc/nginx/sites-available/solvit_ticketing
Gunicorn Service: /etc/systemd/system/solvit_ticketing.service
Socket File: $DEPLOYMENT_DIR/solvit_ticketing.sock
EOF

print_info "Deployment summary saved to: $DEPLOYMENT_DIR/deployment_summary.txt"
echo ""
print_success "🎉 Deployment completed successfully! Your ticketing system is ready to use!"
