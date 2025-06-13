#!/bin/bash

# Django Ticketing System - Nginx Web Server Setup Script (HTTP Only)
# Phase 4: Web server configuration WITHOUT SSL
# Run this script as root after Django app setup

set -e  # Exit on any error

echo "🌐 Django Ticketing System - Nginx Setup (HTTP Only)"
echo "===================================================="
echo "Phase 4: Configuring Nginx web server without SSL"

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

# Get configuration values
if [ -f "/tmp/deployment_config.env" ]; then
    source /tmp/deployment_config.env
else
    print_warning "Configuration file not found. Using defaults."
    DOMAIN="localhost"
    ADMIN_EMAIL="admin@localhost"
fi

# Configuration variables
SERVER_IP=$(curl -s ifconfig.me || echo "127.0.0.1")
APP_DIR="/opt/django-ticketing/app"

print_status "Nginx Configuration (HTTP Only):"
print_info "Domain: $DOMAIN"
print_info "Server IP: $SERVER_IP"
print_info "Application Directory: $APP_DIR"

# Install Nginx
print_status "Installing Nginx..."
apt update
apt install -y nginx

# Create Nginx configuration for Django Ticketing System (HTTP Only)
print_status "Creating Nginx configuration (HTTP Only)..."
cat > /etc/nginx/sites-available/django-ticketing << 'EOF'
# Django Ticketing System Nginx Configuration (HTTP Only)

upstream django_app {
    server unix:/opt/django-ticketing/app/gunicorn.sock fail_timeout=0;
}

# Rate limiting zones
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=general:10m rate=1r/s;

# HTTP Server Configuration
server {
    listen 80;
    listen [::]:80;
    server_name _;  # Accept all hostnames
    
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
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://django_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Static files with caching
    location /static/ {
        alias /opt/django-ticketing/app/static/;
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
        alias /opt/django-ticketing/app/media/;
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
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
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
nginx -t

if [ $? -eq 0 ]; then
    print_status "Nginx configuration is valid!"
else
    print_error "Nginx configuration test failed!"
    exit 1
fi

# Create log directory
mkdir -p /var/log/nginx

# Set proper permissions
chown -R www-data:www-data /var/log/nginx

# Restart and enable Nginx
print_status "Starting Nginx service..."
systemctl restart nginx
systemctl enable nginx

# Configure firewall for HTTP only
print_status "Configuring firewall for HTTP traffic..."
ufw allow 80/tcp
ufw allow 22/tcp
ufw --force enable

# Final status check
print_status "Checking service status..."
systemctl status nginx --no-pager

echo ""
echo "✅ Nginx Setup Complete (HTTP Only)!"
echo "============================================"
echo ""
echo "🌐 Your Django Ticketing System is now accessible at:"
echo "   → http://$SERVER_IP"
if [ "$DOMAIN" != "localhost" ]; then
    echo "   → http://$DOMAIN"
fi
echo ""
echo "📋 Service Status:"
echo "   → Nginx: $(systemctl is-active nginx)"
echo "   → Gunicorn: $(systemctl is-active gunicorn-django-ticketing)"
echo "   → PostgreSQL: $(systemctl is-active postgresql)"
echo ""
echo "📂 Important Paths:"
echo "   → Application: $APP_DIR"
echo "   → Nginx Config: /etc/nginx/sites-available/django-ticketing"
echo "   → Nginx Logs: /var/log/nginx/"
echo "   → Gunicorn Socket: /opt/django-ticketing/app/gunicorn.sock"
echo ""
echo "🔒 Security Features Enabled:"
echo "   → Rate limiting for login/API endpoints"
echo "   → Security headers (without HSTS)"
echo "   → File upload size limits (100MB)"
echo "   → Attack pattern blocking"
echo ""
echo "⚠️  IMPORTANT NOTES:"
echo "   → This deployment uses HTTP only (no SSL/HTTPS)"
echo "   → For production use, consider enabling SSL later"
echo "   → Firewall configured for HTTP (port 80) and SSH (port 22)"
echo ""
echo "🎯 Next Steps:"
echo "   → Test your application at http://$SERVER_IP"
echo "   → Create Django superuser: python manage.py createsuperuser"
echo "   → Configure domain DNS if using custom domain"
echo ""
