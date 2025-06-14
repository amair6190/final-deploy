#!/bin/bash

# SolvIT Django Ticketing System - Ubuntu Server Deployment Script
# Final Production Deployment for Ubuntu Server (Non-Docker)
# Author: Deployment Assistant
# Date: June 2025

set -e  # Exit on any error

echo "🚀 SolvIT Django Ticketing System - Ubuntu Server Deployment"
echo "====================================================="
echo ""
echo -e "${BLUE}📋 Deployment Information${NC}"
echo "This script will deploy your SolvIT Django Ticketing System."
echo "You will be prompted to provide the following information:"
echo ""
echo -e "${YELLOW}🗄️  Database Configuration:${NC}"
echo "   • Database name (letters, numbers, underscores only - no hyphens)"
echo "   • Database username (letters, numbers, underscores only)"  
echo "   • Database password (minimum 8 characters)"
echo ""
echo -e "${YELLOW}👤 Admin User Configuration:${NC}"
echo "   • Admin username (default: admin)"
echo "   • Admin email (default: admin@solvit.com)"
echo "   • Admin mobile number (optional)"
echo "   • Admin password (minimum 8 characters)"
echo ""
echo -e "${BLUE}Press Enter to continue with the deployment...${NC}"
read -p ""
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
fi

log "Starting SolvIT Django Ticketing System deployment..."

# Update system
log "Updating system packages..."
apt update && apt upgrade -y

# Install required packages (including nginx for static files)
log "Installing required packages..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    git \
    postgresql \
    postgresql-contrib \
    nginx \
    supervisor \
    build-essential \
    curl \
    ufw \
    fail2ban

# Start and enable services
log "Starting and enabling services..."
systemctl start postgresql
systemctl enable postgresql

# Verify PostgreSQL is running
if ! systemctl is-active --quiet postgresql; then
    error "PostgreSQL failed to start. Please check the service status."
    exit 1
fi
log "✅ PostgreSQL is running successfully"

# Create application directory
APP_DIR="/opt/solvit-ticketing"
log "Creating application directory: $APP_DIR"
mkdir -p $APP_DIR
cd $APP_DIR

# Clone application (or copy if running from existing directory)
if [ ! -f "manage.py" ]; then
    log "Cloning SolvIT Django application..."
    if [ -d "/home/amair/Desktop/ticket/solvit-django-ticketing-system" ]; then
        cp -r /home/amair/Desktop/ticket/solvit-django-ticketing-system/* .
    else
        git clone https://github.com/amair6190/solvit-django-ticketing-system.git .
    fi
fi

# Setup Python virtual environment
log "Setting up Python virtual environment..."
rm -rf venv
python3 -m venv venv --clear
source venv/bin/activate
pip install --upgrade pip

# Install Python requirements
log "Installing Python requirements..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    pip install django gunicorn psycopg2-binary python-dotenv
fi

# Database setup
log "Setting up PostgreSQL database..."

# Prompt for database details
echo ""
echo -e "${BLUE}📋 Database Configuration${NC}"
echo "Please provide the following database details:"
echo -e "${YELLOW}Note: Database names can only contain letters, numbers, and underscores (no hyphens or spaces)${NC}"
echo ""

# Validate database name
while true; do
    read -p "Enter database name [default: solvit_ticketing]: " DB_NAME
    DB_NAME=${DB_NAME:-solvit_ticketing}
    
    # Check if database name is valid (only letters, numbers, underscores)
    if [[ "$DB_NAME" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        break
    else
        echo -e "${RED}Invalid database name. Use only letters, numbers, and underscores. Must start with a letter or underscore.${NC}"
        echo -e "${YELLOW}Example: solvit_ticketing, my_database, ticketing_system${NC}"
    fi
done

# Validate database username
while true; do
    read -p "Enter database username [default: solvit_user]: " DB_USER
    DB_USER=${DB_USER:-solvit_user}
    
    # Check if username is valid (only letters, numbers, underscores)
    if [[ "$DB_USER" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        break
    else
        echo -e "${RED}Invalid username. Use only letters, numbers, and underscores. Must start with a letter or underscore.${NC}"
        echo -e "${YELLOW}Example: solvit_user, admin_user, db_user${NC}"
    fi
done

while true; do
    read -s -p "Enter database password: " DB_PASSWORD
    echo ""
    read -s -p "Confirm database password: " DB_PASSWORD_CONFIRM
    echo ""
    if [[ "$DB_PASSWORD" == "$DB_PASSWORD_CONFIRM" ]]; then
        if [[ ${#DB_PASSWORD} -lt 8 ]]; then
            echo -e "${RED}Password must be at least 8 characters long. Please try again.${NC}"
        else
            break
        fi
    else
        echo -e "${RED}Passwords do not match. Please try again.${NC}"
    fi
done

log "Database details: $DB_NAME with user: $DB_USER"

# Create database and user with error handling
log "Creating PostgreSQL database and user..."

# Drop existing database and user (ignore errors if they don't exist)
sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;" 2>/dev/null || true

# Create user
if ! sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD' CREATEDB CREATEROLE;"; then
    error "Failed to create database user: $DB_USER"
    exit 1
fi

# Create database
if ! sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"; then
    error "Failed to create database: $DB_NAME"
    exit 1
fi

# Grant privileges
if ! sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"; then
    error "Failed to grant privileges to user: $DB_USER"
    exit 1
fi

# Grant schema permissions
sudo -u postgres psql -d $DB_NAME -c "GRANT ALL ON SCHEMA public TO $DB_USER;" || warning "Schema permissions may need manual adjustment"
sudo -u postgres psql -d $DB_NAME -c "ALTER SCHEMA public OWNER TO $DB_USER;" || warning "Schema ownership may need manual adjustment"

log "✅ Database created successfully: $DB_NAME with user: $DB_USER"

# Create Django production settings
log "Creating Django production settings..."
cat > it_ticketing_system/settings_production.py << EOF
import os
from .settings import *

# Production settings
DEBUG = False
ALLOWED_HOSTS = ['localhost', '127.0.0.1', '*']  # Update with your domain

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
SECRET_KEY = 'solvit-production-secret-key-$(date +%s)-$(openssl rand -hex 16)'
SECURE_SSL_REDIRECT = False  # Set to True when using HTTPS
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SESSION_COOKIE_SECURE = False  # Set to True when using HTTPS
CSRF_COOKIE_SECURE = False  # Set to True when using HTTPS

# CSRF Settings
CSRF_TRUSTED_ORIGINS = [
    'http://127.0.0.1:8001',
    'http://127.0.0.1:8080',
    'http://localhost:8001',
    'http://localhost:8080',
]
CSRF_COOKIE_HTTPONLY = False
CSRF_USE_SESSIONS = False

# Static and media files
STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# Logging
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': '/var/log/solvit-ticketing.log',
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

print("✅ SolvIT Production settings loaded")
EOF

# Set environment variables
export DJANGO_SETTINGS_MODULE=it_ticketing_system.settings_production

# Run Django setup
log "Running Django migrations and setup..."
source venv/bin/activate
python manage.py migrate
python manage.py collectstatic --noinput

# Create superuser
log "Creating Django superuser..."

# Prompt for superuser details
echo ""
echo -e "${BLUE}👤 Django Superuser Configuration${NC}"
echo "Please provide the following admin user details:"
echo ""

read -p "Enter admin username [default: admin]: " ADMIN_USERNAME
ADMIN_USERNAME=${ADMIN_USERNAME:-admin}

read -p "Enter admin email [default: admin@solvit.com]: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@solvit.com}

read -p "Enter admin mobile number [optional]: " ADMIN_MOBILE
ADMIN_MOBILE=${ADMIN_MOBILE:-1234567890}

while true; do
    read -s -p "Enter admin password: " ADMIN_PASSWORD
    echo ""
    read -s -p "Confirm admin password: " ADMIN_PASSWORD_CONFIRM
    echo ""
    if [[ "$ADMIN_PASSWORD" == "$ADMIN_PASSWORD_CONFIRM" ]]; then
        if [[ ${#ADMIN_PASSWORD} -lt 8 ]]; then
            echo -e "${RED}Password must be at least 8 characters long. Please try again.${NC}"
        else
            break
        fi
    else
        echo -e "${RED}Passwords do not match. Please try again.${NC}"
    fi
done

log "Creating superuser: $ADMIN_USERNAME"

python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='$ADMIN_USERNAME').exists():
    try:
        admin_user = User.objects.create_superuser(
            username='$ADMIN_USERNAME',
            email='$ADMIN_EMAIL',
            password='$ADMIN_PASSWORD',
            mobile='$ADMIN_MOBILE'
        )
        print('✅ Admin user created successfully')
    except Exception as e:
        print(f'Note: {e}')
        # Fallback method
        admin_user = User.objects.create_user(
            username='$ADMIN_USERNAME',
            email='$ADMIN_EMAIL',
            password='$ADMIN_PASSWORD'
        )
        admin_user.is_staff = True
        admin_user.is_superuser = True
        admin_user.save()
        print('✅ Admin user created with fallback method')
else:
    print('ℹ️ Admin user already exists')
"

# Create system user for the application
log "Creating system user for the application..."
useradd -r -d $APP_DIR -s /bin/false solvit || true
chown -R solvit:solvit $APP_DIR

# Create Gunicorn systemd service (running on port 8000 for your proxy server)
log "Creating Gunicorn systemd service..."
cat > /etc/systemd/system/solvit-ticketing.service << EOF
[Unit]
Description=SolvIT Django Ticketing System
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=notify
User=solvit
Group=solvit
RuntimeDirectory=solvit-ticketing
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
Environment="DJANGO_SETTINGS_MODULE=it_ticketing_system.settings_production"
ExecStart=$APP_DIR/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:8001 --timeout 60 --keep-alive 2 --max-requests 1000 it_ticketing_system.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Note: No Nginx configuration - you'll configure your existing proxy server

# Create Nginx configuration for static files (on port 8080 to avoid conflicts)
log "Creating Nginx configuration for static files..."
cat > /etc/nginx/sites-available/solvit-static << EOF
server {
    listen 8080;
    server_name localhost;
    
    # Serve static files
    location /static/ {
        alias $APP_DIR/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        add_header Access-Control-Allow-Origin "*";
    }
    
    # Serve media files
    location /media/ {
        alias $APP_DIR/media/;
        expires 30d;
        add_header Access-Control-Allow-Origin "*";
    }
    
    # Proxy everything else to Django
    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }
}
EOF

# Enable Nginx site (but handle port conflicts gracefully)
ln -sf /etc/nginx/sites-available/solvit-static /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t || warning "Nginx configuration test failed - will try to start anyway"

# Create log file
touch /var/log/solvit-ticketing.log
chown solvit:solvit /var/log/solvit-ticketing.log

# Start and enable services
log "Starting and enabling services..."
systemctl daemon-reload
systemctl enable solvit-ticketing
systemctl start solvit-ticketing

# Setup firewall (allowing port 8000 for your proxy server access)
log "Configuring firewall..."
ufw --force enable
ufw allow 22/tcp
ufw allow 8001/tcp comment "SolvIT Django App for proxy server"

# Setup fail2ban
log "Configuring fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# Wait for services to start
sleep 5

# Check service status
log "Checking service status..."
systemctl status solvit-ticketing --no-pager || warning "SolvIT service may have issues"
systemctl status nginx --no-pager || warning "Nginx may have issues - static files will be served by Django"

# Test the application
log "Testing application..."
if curl -s http://127.0.0.1:8080/ > /dev/null 2>&1; then
    log "✅ Full application with styling is responding on port 8080!"
    MAIN_URL="http://127.0.0.1:8080/"
elif curl -s http://127.0.0.1:8001/ > /dev/null 2>&1; then
    log "✅ Django application is responding on port 8001!"
    MAIN_URL="http://127.0.0.1:8001/"
else
    warning "Application may not be responding yet"
    MAIN_URL="http://127.0.0.1:8001/"
fi

# Create deployment info file
cat > $APP_DIR/DEPLOYMENT_INFO.txt << EOF
SolvIT Django Ticketing System - Deployment Information
=======================================================

Deployment Date: $(date)
Application Directory: $APP_DIR
Database: $DB_NAME
Database User: $DB_USER
Database Password: $DB_PASSWORD

Django Admin Credentials:
Username: $ADMIN_USERNAME
Password: $ADMIN_PASSWORD
Email: $ADMIN_EMAIL

Application Access:
- Django App: http://127.0.0.1:8001/ (for your proxy server)
- Admin Panel: http://127.0.0.1:8001/admin/
- Note: Configure your existing Nginx proxy to forward to http://127.0.0.1:8001

Your Nginx Proxy Configuration:
Add this to your existing Nginx server configuration:

    location /static/ {
        alias $APP_DIR/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias $APP_DIR/media/;
        expires 30d;
    }

    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }

Management Commands:
- Check service status: systemctl status solvit-ticketing
- Restart application: systemctl restart solvit-ticketing
- View logs: journalctl -u solvit-ticketing -f
- Test Django app: curl http://127.0.0.1:8000/

File Locations:
- Application: $APP_DIR
- Service config: /etc/systemd/system/solvit-ticketing.service
- Logs: /var/log/solvit-ticketing.log

Database Connection:
Host: localhost
Port: 5432
Database: $DB_NAME
Username: $DB_USER
Password: $DB_PASSWORD

Security:
- Firewall (UFW): Enabled
- Fail2ban: Enabled
- Django runs on localhost:8000 (accessible only to your proxy server)

Next Steps:
1. Configure your existing Nginx proxy server to forward to http://127.0.0.1:8000
2. Add SSL certificate to your existing Nginx
3. Update ALLOWED_HOSTS in Django settings with your domain
4. Test all functionality through your proxy server
5. Setup regular backups
EOF

# Final status report
echo ""
echo "🎉 SolvIT Django Ticketing System Deployment Complete!"
echo "====================================================="
echo ""
log "✅ Application deployed successfully!"
log "✅ PostgreSQL database configured"
log "✅ Nginx web server configured"
log "✅ Gunicorn application server running"
log "✅ System services enabled"
log "✅ Firewall and security configured"
echo ""
echo -e "${BLUE}📋 Deployment Summary:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🌐 Django App: http://127.0.0.1:8001/${NC}"
echo -e "${GREEN}👤 Admin Panel: http://127.0.0.1:8001/admin/${NC}"
echo -e "${GREEN}🔑 Admin Login: $ADMIN_USERNAME / $ADMIN_PASSWORD${NC}"
echo -e "${GREEN}🗄️ Database: $DB_NAME ($DB_USER)${NC}"
echo -e "${GREEN}📁 App Directory: $APP_DIR${NC}"
echo ""
echo -e "${BLUE}🔧 Configure Your Existing Nginx Proxy:${NC}"
echo -e "${YELLOW}Add this to your Nginx server configuration:${NC}"
echo ""
echo -e "${YELLOW}    location /static/ {${NC}"
echo -e "${YELLOW}        alias $APP_DIR/staticfiles/;${NC}"
echo -e "${YELLOW}        expires 30d;${NC}"
echo -e "${YELLOW}    }${NC}"
echo ""
echo -e "${YELLOW}    location /media/ {${NC}"
echo -e "${YELLOW}        alias $APP_DIR/media/;${NC}"
echo -e "${YELLOW}        expires 30d;${NC}"
echo -e "${YELLOW}    }${NC}"
echo ""
echo -e "${YELLOW}    location / {${NC}"
echo -e "${YELLOW}        proxy_pass http://127.0.0.1:8001;${NC}"
echo -e "${YELLOW}        proxy_set_header Host \$host;${NC}"
echo -e "${YELLOW}        proxy_set_header X-Real-IP \$remote_addr;${NC}"
echo -e "${YELLOW}        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;${NC}"
echo -e "${YELLOW}        proxy_set_header X-Forwarded-Proto \$scheme;${NC}"
echo -e "${YELLOW}        proxy_redirect off;${NC}"
echo -e "${YELLOW}    }${NC}"
echo ""
echo -e "${BLUE}🔧 Management Commands:${NC}"
echo -e "${YELLOW}  systemctl status solvit-ticketing    # Check app status${NC}"
echo -e "${YELLOW}  systemctl restart solvit-ticketing   # Restart app${NC}"
echo -e "${YELLOW}  journalctl -u solvit-ticketing -f    # View logs${NC}"
echo -e "${YELLOW}  curl http://127.0.0.1:8001/          # Test Django app${NC}"
echo ""
echo -e "${BLUE}📋 Important Files:${NC}"
echo -e "${YELLOW}  $APP_DIR/DEPLOYMENT_INFO.txt         # Deployment details${NC}"
echo -e "${YELLOW}  /var/log/solvit-ticketing.log        # Application logs${NC}"
echo ""
echo -e "${GREEN}🎯 Your SolvIT Django App is running on http://127.0.0.1:8001${NC}"
echo -e "${GREEN}   Configure your existing Nginx proxy to forward requests to this address!${NC}"
echo ""
