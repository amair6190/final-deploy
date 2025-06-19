#!/bin/bash

# SolvIT Ticketing System - Domain Setup Script
# This script configures your ticketing system to work with a domain name
# Usage: sudo ./setup-domain.sh yourdomain.com

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root or with sudo privileges${NC}" 
   exit 1
fi

# Check for domain argument
if [ -z "$1" ]; then
    echo -e "${RED}Error: Domain name not provided${NC}"
    echo "Usage: sudo $0 yourdomain.com"
    exit 1
fi

DOMAIN=$1
APP_DIR=$(pwd)
PUBLIC_IP=$(curl -s ifconfig.me)

echo -e "${BLUE}🚀 SolvIT Django Ticketing System - Domain Configuration${NC}"
echo "====================================================="
echo ""
echo -e "${YELLOW}Domain:${NC} $DOMAIN"
echo -e "${YELLOW}Public IP:${NC} $PUBLIC_IP"
echo -e "${YELLOW}App Directory:${NC} $APP_DIR"
echo ""

# Update the .env file with domain
echo -e "${GREEN}Updating .env file with domain settings...${NC}"
if [ -f ".env" ]; then
    # Backup existing .env
    cp .env .env.backup.$(date +%Y%m%d%H%M%S)
    
    # Update or add ALLOWED_HOSTS
    if grep -q "ALLOWED_HOSTS" .env; then
        # Add the domain to existing ALLOWED_HOSTS
        sed -i "s/ALLOWED_HOSTS=.*/ALLOWED_HOSTS=127.0.0.1,localhost,$DOMAIN,www.$DOMAIN/" .env
    else
        # Add new ALLOWED_HOSTS entry
        echo "ALLOWED_HOSTS=127.0.0.1,localhost,$DOMAIN,www.$DOMAIN" >> .env
    fi
    
    # Update or add security settings
    grep -q "SECURE_SSL_REDIRECT" .env || echo "SECURE_SSL_REDIRECT=True" >> .env
    grep -q "SECURE_HSTS_SECONDS" .env || echo "SECURE_HSTS_SECONDS=31536000" >> .env
    grep -q "SECURE_HSTS_INCLUDE_SUBDOMAINS" .env || echo "SECURE_HSTS_INCLUDE_SUBDOMAINS=True" >> .env
    grep -q "SECURE_HSTS_PRELOAD" .env || echo "SECURE_HSTS_PRELOAD=True" >> .env
else
    echo -e "${YELLOW}Warning: .env file not found. Creating new .env file...${NC}"
    cat > .env << EOF
# SolvIT Ticketing System Environment Variables
DEBUG=False
SECRET_KEY=$(python -c 'import random; print("".join([random.choice("abcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*(-_=+)") for i in range(50)]))')
ALLOWED_HOSTS=127.0.0.1,localhost,$DOMAIN,www.$DOMAIN
SECURE_SSL_REDIRECT=True
SECURE_HSTS_SECONDS=31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS=True
SECURE_HSTS_PRELOAD=True
ADMIN_URL=admin/
EOF
fi

# Create Nginx configuration for the domain
echo -e "${GREEN}Creating Nginx configuration for $DOMAIN...${NC}"
cat > /etc/nginx/sites-available/solvit-$DOMAIN << EOF
server {
    # Redirect HTTP to HTTPS
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    
    # For Let's Encrypt certificate validation
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect all HTTP requests to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    # Main server block (will be configured for HTTPS after SSL certificate is installed)
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    # Static files
    location /static/ {
        alias $APP_DIR/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Media files
    location /media/ {
        alias $APP_DIR/media/;
        expires 30d;
    }
    
    # Proxy Django application requests
    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        
        # Timeout settings
        proxy_connect_timeout 75s;
        proxy_send_timeout 75s;
        proxy_read_timeout 90s;
    }
    
    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    
    # Logs
    access_log /var/log/nginx/solvit-access.log;
    error_log /var/log/nginx/solvit-error.log;
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/solvit-$DOMAIN /etc/nginx/sites-enabled/

# Test Nginx configuration
echo -e "${GREEN}Testing Nginx configuration...${NC}"
nginx -t

# Restart Nginx
echo -e "${GREEN}Restarting Nginx...${NC}"
systemctl restart nginx

# Update firewall rules
echo -e "${GREEN}Updating firewall rules...${NC}"
ufw allow 80/tcp
ufw allow 443/tcp

# Install SSL Certificate with Certbot
echo -e "${GREEN}Setting up SSL certificate with Let's Encrypt...${NC}"
if ! command -v certbot &> /dev/null; then
    echo -e "${YELLOW}Installing Certbot...${NC}"
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

echo -e "${BLUE}Obtaining SSL certificate from Let's Encrypt...${NC}"
echo -e "${YELLOW}Note: Your domain must be properly configured in DNS to point to this server (IP: $PUBLIC_IP) for this step to work.${NC}"
certbot --nginx -d $DOMAIN -d www.$DOMAIN

# Restart the Django application
echo -e "${GREEN}Restarting the SolvIT Ticketing System...${NC}"
systemctl restart solvit-ticketing

echo ""
echo -e "${BLUE}🎉 Domain Configuration Complete!${NC}"
echo "====================================================="
echo -e "${GREEN}Your SolvIT Ticketing System is now accessible at:${NC}"
echo -e "${BLUE}https://$DOMAIN${NC}"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "1. Please make sure your DNS settings are properly configured to point to this server's IP: $PUBLIC_IP"
echo "2. SSL certificates will auto-renew with the installed cron job"
echo "3. If you experience issues, check the logs at /var/log/nginx/solvit-error.log"
echo ""
echo -e "${GREEN}If you need to make changes to your domain configuration, edit the files at:${NC}"
echo "/etc/nginx/sites-available/solvit-$DOMAIN"
echo ""
