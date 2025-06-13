#!/bin/bash

# Django Ticketing System - Nginx Web Server Setup Script
# Phase 4: Web server configuration and SSL setup
# Run this script as root after Django app setup

set -e  # Exit on any error

echo "🌐 Django Ticketing System - Nginx Setup"
echo "========================================"
echo "Phase 4: Configuring Nginx web server and SSL"

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
DOMAIN="your-domain.com"  # Change this to your actual domain
SERVER_IP=$(curl -s ifconfig.me || echo "your-server-ip")
APP_DIR="/opt/django-ticketing/app"

print_status "Nginx Configuration:"
print_info "Domain: $DOMAIN"
print_info "Server IP: $SERVER_IP"
print_info "Application Directory: $APP_DIR"

# Install additional Nginx modules if needed
print_status "Installing Nginx additional modules..."
apt install -y nginx-extras

# Create Nginx configuration for Django Ticketing System
print_status "Creating Nginx configuration..."
cat > /etc/nginx/sites-available/django-ticketing << EOF
# Django Ticketing System Nginx Configuration
# Generated on $(date)

upstream django_ticketing {
    server unix:/opt/django-ticketing/app/gunicorn.sock fail_timeout=0;
}

# Rate limiting zones
limit_req_zone \$binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone \$binary_remote_addr zone=general:10m rate=1r/s;

# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN $SERVER_IP;
    
    # Allow Let's Encrypt challenges
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect everything else to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS Server Configuration
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    
    # SSL Configuration (certificates will be added by Certbot)
    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https:; connect-src 'self';" always;
    
    # File upload size limits
    client_max_body_size 50M;
    client_body_buffer_size 128k;
    client_body_timeout 60s;
    client_header_timeout 60s;
    
    # Gzip compression
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
    
    # Static files with caching
    location /static/ {
        alias /opt/django-ticketing/app/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        add_header Vary "Accept-Encoding";
        
        # Security for static files
        location ~* \.(js|css)$ {
            add_header Content-Type application/javascript;
            add_header Content-Type text/css;
        }
    }
    
    # Media files with caching
    location /media/ {
        alias /opt/django-ticketing/app/media/;
        expires 7d;
        add_header Cache-Control "public";
        add_header Vary "Accept-Encoding";
        
        # Security for uploaded files
        location ~* \.(php|py|pl|sh|cgi)$ {
            deny all;
        }
    }
    
    # Favicon
    location = /favicon.ico {
        alias /opt/django-ticketing/app/static/images/favicon.ico;
        expires 30d;
        add_header Cache-Control "public, immutable";
        log_not_found off;
    }
    
    # Robots.txt
    location = /robots.txt {
        alias /opt/django-ticketing/app/static/robots.txt;
        expires 30d;
        add_header Cache-Control "public, immutable";
        log_not_found off;
    }
    
    # Admin panel with rate limiting and IP restriction
    location /admin/ {
        # Rate limiting for admin
        limit_req zone=login burst=3 nodelay;
        
        # IP whitelist for admin (uncomment and add your IPs)
        # allow 192.168.1.0/24;
        # allow your.admin.ip.address;
        # deny all;
        
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        proxy_buffering off;
        proxy_pass http://django_ticketing;
    }
    
    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        proxy_buffering off;
        proxy_pass http://django_ticketing;
    }
    
    # Login pages with rate limiting
    location ~ ^/(login|register)/ {
        limit_req zone=login burst=5 nodelay;
        
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        proxy_buffering off;
        proxy_pass http://django_ticketing;
    }
    
    # Main Django application
    location / {
        limit_req zone=general burst=10 nodelay;
        
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        proxy_buffering off;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_pass http://django_ticketing;
    }
    
    # Health check endpoint
    location /health/ {
        access_log off;
        proxy_pass http://django_ticketing;
    }
    
    # Security: Block access to sensitive files
    location ~ /\. {
        deny all;
        log_not_found off;
    }
    
    location ~ /(\.git|\.env|requirements\.txt|manage\.py|\.py\$) {
        deny all;
        log_not_found off;
    }
    
    # Block common attack patterns
    location ~* (wp-admin|wp-login|phpmyadmin|admin\.php) {
        deny all;
        log_not_found off;
    }
}

# Fallback server for unmatched hosts
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    
    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
    
    server_name _;
    return 444;  # Close connection without response
}
EOF

# Create self-signed SSL certificate for initial setup
print_status "Creating self-signed SSL certificate..."
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/nginx-selfsigned.key \
    -out /etc/ssl/certs/nginx-selfsigned.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=$DOMAIN"

chmod 600 /etc/ssl/private/nginx-selfsigned.key

# Create robots.txt
print_status "Creating robots.txt..."
mkdir -p "$APP_DIR/static"
cat > "$APP_DIR/static/robots.txt" << 'EOF'
User-agent: *
Disallow: /admin/
Disallow: /api/
Disallow: /media/ticket_attachments/
Disallow: /media/message_attachments/
Allow: /

Sitemap: https://your-domain.com/sitemap.xml
EOF

chown django-user:django-user "$APP_DIR/static/robots.txt"

# Enable the site and disable default
print_status "Enabling Django Ticketing System site..."
ln -sf /etc/nginx/sites-available/django-ticketing /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
print_status "Testing Nginx configuration..."
if nginx -t; then
    print_status "✅ Nginx configuration is valid"
else
    print_error "❌ Nginx configuration has errors"
    exit 1
fi

# Create Nginx optimization configuration
print_status "Creating Nginx optimization configuration..."
cat > /etc/nginx/conf.d/django-ticketing-optimization.conf << 'EOF'
# Django Ticketing System Nginx Optimization

# Worker processes optimization
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

# HTTP optimization
http {
    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    # Buffer sizes
    client_body_buffer_size 128k;
    client_max_body_size 50m;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 4k;
    output_buffers 1 32k;
    postpone_output 1460;
    
    # Timeouts
    client_header_timeout 3m;
    client_body_timeout 3m;
    send_timeout 3m;
    
    # Open file cache
    open_file_cache max=1000 inactive=20s;
    open_file_cache_valid 30s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;
}
EOF

# Install Certbot for Let's Encrypt SSL
print_status "Installing Certbot for Let's Encrypt SSL..."
apt install -y certbot python3-certbot-nginx

# Create SSL renewal script
print_status "Creating SSL certificate auto-renewal..."
cat > /opt/django-ticketing/renew_ssl.sh << 'EOF'
#!/bin/bash
# SSL Certificate Renewal Script for Django Ticketing System

echo "🔒 Renewing SSL certificates..."

# Renew certificates
certbot renew --quiet

# Reload Nginx if certificates were renewed
if [ $? -eq 0 ]; then
    systemctl reload nginx
    echo "✅ SSL certificates renewed and Nginx reloaded"
else
    echo "⚠️ No certificate renewal needed"
fi
EOF

chmod +x /opt/django-ticketing/renew_ssl.sh

# Add SSL renewal to crontab
cat > /etc/cron.d/django-ticketing-ssl << 'EOF'
# SSL certificate renewal for Django Ticketing System
0 2 * * 0 root /opt/django-ticketing/renew_ssl.sh >> /opt/django-ticketing/logs/ssl_renewal.log 2>&1
EOF

# Create Nginx log rotation
print_status "Setting up Nginx log rotation..."
cat > /etc/logrotate.d/django-ticketing-nginx << 'EOF'
/var/log/nginx/access.log /var/log/nginx/error.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            kill -USR1 `cat /var/run/nginx.pid`
        fi
    endscript
}
EOF

# Start and enable services
print_status "Starting and enabling services..."
systemctl enable nginx
systemctl enable redis-server
systemctl start redis-server
systemctl start django-ticketing
systemctl restart nginx

# Create monitoring script
print_status "Creating monitoring script..."
cat > /opt/django-ticketing/monitor_services.sh << 'EOF'
#!/bin/bash
# Service monitoring script for Django Ticketing System

SERVICES=("nginx" "postgresql" "redis-server" "django-ticketing")
EMAIL_ALERT="admin@your-domain.com"  # Change this to your email

for service in "${SERVICES[@]}"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "❌ $service is not running!"
        
        # Try to restart the service
        systemctl restart "$service"
        sleep 5
        
        if systemctl is-active --quiet "$service"; then
            echo "✅ $service restarted successfully"
        else
            echo "❌ Failed to restart $service"
            # Send email alert (requires mail command to be configured)
            # echo "$service failed on $(hostname) at $(date)" | mail -s "Service Alert" "$EMAIL_ALERT"
        fi
    else
        echo "✅ $service is running"
    fi
done
EOF

chmod +x /opt/django-ticketing/monitor_services.sh

# Add monitoring to crontab
cat > /etc/cron.d/django-ticketing-monitor << 'EOF'
# Service monitoring for Django Ticketing System
*/5 * * * * root /opt/django-ticketing/monitor_services.sh >> /opt/django-ticketing/logs/monitor.log 2>&1
EOF

print_status "✅ Phase 4 Complete: Nginx web server configured"
print_status "📋 Nginx Summary:"
echo "   - Configuration: /etc/nginx/sites-available/django-ticketing"
echo "   - SSL Certificate: Self-signed (replace with Let's Encrypt)"
echo "   - Rate limiting enabled for security"
echo "   - Security headers configured"
echo "   - Gzip compression enabled"
echo "   - Log rotation configured"
echo "   - Auto-monitoring setup"
echo ""
print_warning "🔒 SSL Certificate Setup:"
echo "   1. Update domain in configuration files"
echo "   2. Run: certbot --nginx -d $DOMAIN -d www.$DOMAIN"
echo "   3. Test SSL: https://www.ssllabs.com/ssltest/"
echo ""
print_status "🔄 Next: Run 05-security-hardening.sh for final security setup"
