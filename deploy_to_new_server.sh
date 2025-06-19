#!/bin/bash

# SolvIT Ticketing System - Complete Deployment Script for Ubuntu Server
# This script will deploy the SolvIT Ticketing System on a new Ubuntu server
# Target Server IP: 10.0.0.18

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running with sudo/root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root or with sudo privileges${NC}"
    exit 1
fi

# Display welcome message
echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      SolvIT Ticketing System - Full Deployment   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo -e "${YELLOW}This script will deploy the SolvIT Ticketing System to your Ubuntu server.${NC}"
echo -e "${YELLOW}Target Server: 10.0.0.18${NC}\n"

# Confirm deployment
read -p "Do you want to proceed with deployment? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo -e "${RED}Deployment cancelled.${NC}"
    exit 1
fi

# System variables
APP_DIR="/opt/solvit-ticketing"
REPO_DIR="/home/amair/Desktop/deploy-ticket/solvit-ticketing-system-v2"
SERVER_IP="10.0.0.18"
DOMAIN="support.solvitservices.com"
SRC_SERVER="10.0.0.95"  # Current server with the application

echo -e "\n${GREEN}Step 1: System Update and Package Installation${NC}"
echo -e "${YELLOW}Updating system packages...${NC}"
apt-get update
apt-get upgrade -y

echo -e "${YELLOW}Installing required packages...${NC}"
apt-get install -y python3 python3-pip python3-venv postgresql postgresql-contrib nginx certbot python3-certbot-nginx git curl ufw fail2ban

# Create application directory
echo -e "\n${GREEN}Step 2: Setting Up Application Directory${NC}"
echo -e "${YELLOW}Creating application directory...${NC}"
mkdir -p $APP_DIR
cd $APP_DIR

# Copy application files from source server
echo -e "\n${GREEN}Step 3: Copying Application Files${NC}"
echo -e "${YELLOW}Copying application files from source server ($SRC_SERVER)...${NC}"
echo -e "${YELLOW}Option 1: Using scp (secure copy) - recommended${NC}"
echo -e "${BLUE}Run this command on your current server:${NC}"
echo "sudo rsync -avz /home/amair/Desktop/deploy-ticket/solvit-ticketing-system-v2/ root@$SERVER_IP:$APP_DIR/"

echo -e "${YELLOW}Option 2: Clone from repository (if available)${NC}"
echo -e "${BLUE}Run this command on the target server:${NC}"
echo "git clone https://github.com/yourusername/solvit-ticketing-system.git $APP_DIR"

echo -e "\n${YELLOW}Press Enter after copying application files to continue...${NC}"
read -p ""

# Database setup
echo -e "\n${GREEN}Step 4: Setting up PostgreSQL Database${NC}"
echo -e "${YELLOW}Setting up PostgreSQL database...${NC}"
# Prompt for database details
read -p "Enter database name [default: solvit_ticketing]: " DB_NAME
DB_NAME=${DB_NAME:-solvit_ticketing}

read -p "Enter database username [default: solvit_user]: " DB_USER
DB_USER=${DB_USER:-solvit_user}

read -s -p "Enter database password [default: SolvITdb@2025]: " DB_PASSWORD
DB_PASSWORD=${DB_PASSWORD:-SolvITdb@2025}
echo ""

# Create database and user
echo -e "${YELLOW}Creating database and user...${NC}"
sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "ALTER USER $DB_USER CREATEDB;"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
echo -e "${GREEN}Database setup complete.${NC}"

# Set up Python environment
echo -e "\n${GREEN}Step 5: Setting up Python Environment${NC}"
echo -e "${YELLOW}Creating virtual environment...${NC}"
python3 -m venv $APP_DIR/venv
source $APP_DIR/venv/bin/activate
pip install --upgrade pip

# Install dependencies
echo -e "${YELLOW}Installing Python dependencies...${NC}"
pip install -r $APP_DIR/requirements.txt
pip install gunicorn psycopg2-binary python-dotenv django-jazzmin

# Create .env file
echo -e "\n${GREEN}Step 6: Creating Environment Configuration${NC}"
echo -e "${YELLOW}Creating .env file...${NC}"
cat > $APP_DIR/.env << EOF
DEBUG=False
SECRET_KEY=$(python -c 'import random; import string; print("".join([random.choice(string.ascii_letters + string.digits + string.punctuation) for _ in range(50)]))')
ALLOWED_HOSTS=127.0.0.1,localhost,$SERVER_IP,$DOMAIN,www.$DOMAIN
DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@localhost/${DB_NAME}
SECURE_SSL_REDIRECT=False
CSRF_TRUSTED_ORIGINS=http://127.0.0.1:8001,http://${SERVER_IP}:8001,https://${DOMAIN},http://${DOMAIN},https://www.${DOMAIN},http://www.${DOMAIN}
ADMIN_URL=admin/
EOF

# Update Django settings for CSRF
echo -e "${YELLOW}Ensuring CSRF settings are properly configured...${NC}"
grep -q "CSRF_TRUSTED_ORIGINS" $APP_DIR/it_ticketing_system/settings_production.py || {
    echo -e "${YELLOW}Adding CSRF_TRUSTED_ORIGINS to settings...${NC}"
    sed -i '/CSRF_COOKIE_SAMESITE/a \
\
# CSRF Trusted Origins (for cross-origin requests with domains)\
CSRF_TRUSTED_ORIGINS = env.list("CSRF_TRUSTED_ORIGINS", default=[\
    "https://'"${DOMAIN}"'",\
    "http://'"${DOMAIN}"'",\
    "http://'"${SERVER_IP}"':8001",\
])' $APP_DIR/it_ticketing_system/settings_production.py
}

# Django migrations and static files
echo -e "\n${GREEN}Step 7: Django Setup and Initialization${NC}"
echo -e "${YELLOW}Running Django migrations...${NC}"
cd $APP_DIR
python manage.py migrate --settings=it_ticketing_system.settings_production

echo -e "${YELLOW}Collecting static files...${NC}"
python manage.py collectstatic --noinput --settings=it_ticketing_system.settings_production

# Create superuser
echo -e "${YELLOW}Creating superuser...${NC}"
read -p "Enter admin username [default: admin]: " ADMIN_USER
ADMIN_USER=${ADMIN_USER:-admin}

read -p "Enter admin email [default: admin@solvit.com]: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@solvit.com}

read -s -p "Enter admin password [default: SolvIT@2025]: " ADMIN_PASSWORD
ADMIN_PASSWORD=${ADMIN_PASSWORD:-SolvIT@2025}
echo ""

python manage.py shell --settings=it_ticketing_system.settings_production -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='$ADMIN_USER').exists():
    User.objects.create_superuser('$ADMIN_USER', '$ADMIN_EMAIL', '$ADMIN_PASSWORD')
    print('Admin user created successfully')
else:
    print('Admin user already exists')
"

# Create system user
echo -e "\n${GREEN}Step 8: Creating System User${NC}"
echo -e "${YELLOW}Creating system user for the application...${NC}"
useradd -r -d $APP_DIR -s /bin/false solvit || true
chown -R solvit:solvit $APP_DIR

# Set up Gunicorn systemd service
echo -e "\n${GREEN}Step 9: Setting up Gunicorn Service${NC}"
echo -e "${YELLOW}Creating Gunicorn systemd service...${NC}"
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
ExecStart=$APP_DIR/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:8001 --timeout 60 --keep-alive 2 --max-requests 1000 it_ticketing_system.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Start and enable Gunicorn service
echo -e "${YELLOW}Starting Gunicorn service...${NC}"
systemctl daemon-reload
systemctl start solvit-ticketing
systemctl enable solvit-ticketing

# Set up Nginx
echo -e "\n${GREEN}Step 10: Setting up Nginx${NC}"
echo -e "${YELLOW}Creating Nginx configuration...${NC}"
cat > /etc/nginx/sites-available/solvit << EOF
server {
    listen 80;
    server_name $SERVER_IP $DOMAIN www.$DOMAIN;

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

    # For Let's Encrypt certificate validation
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Proxy Django application requests
    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Origin \$scheme://\$host;
        
        # WebSocket support (if needed)
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
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

# Enable Nginx site
echo -e "${YELLOW}Enabling Nginx site...${NC}"
ln -sf /etc/nginx/sites-available/solvit /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
echo -e "${YELLOW}Testing Nginx configuration...${NC}"
nginx -t

# Start/restart Nginx
echo -e "${YELLOW}Restarting Nginx...${NC}"
systemctl restart nginx
systemctl enable nginx

# Set up firewall
echo -e "\n${GREEN}Step 11: Setting up Firewall${NC}"
echo -e "${YELLOW}Configuring firewall...${NC}"
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw allow 8001/tcp comment "SolvIT Django App"
echo "y" | ufw enable

# Set up fail2ban
echo -e "${YELLOW}Configuring fail2ban...${NC}"
systemctl enable fail2ban
systemctl start fail2ban

# SSL certificate
echo -e "\n${GREEN}Step 12: SSL Certificate Setup${NC}"
echo -e "${YELLOW}Would you like to set up SSL certificate for $DOMAIN? (y/n):${NC}"
read setup_ssl
if [[ "$setup_ssl" == "y" || "$setup_ssl" == "Y" ]]; then
    echo -e "${YELLOW}Setting up SSL certificate with Let's Encrypt...${NC}"
    certbot --nginx -d $DOMAIN -d www.$DOMAIN
else
    echo -e "${YELLOW}SSL certificate setup skipped. You can set it up later with:${NC}"
    echo "sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN"
fi

# Final checks
echo -e "\n${GREEN}Step 13: Final Checks${NC}"
# Check service status
echo -e "${YELLOW}Checking service status...${NC}"
systemctl status solvit-ticketing --no-pager
systemctl status nginx --no-pager

# Test application
echo -e "${YELLOW}Testing application access...${NC}"
curl -s -I http://127.0.0.1:8001 >/dev/null && echo -e "${GREEN}✓ Application is accessible on localhost${NC}" || echo -e "${RED}✗ Application is not accessible on localhost${NC}"
curl -s -I http://$SERVER_IP:8001 >/dev/null && echo -e "${GREEN}✓ Application is accessible via IP${NC}" || echo -e "${RED}✗ Application is not accessible via IP${NC}"

# Create deployment info file
echo -e "\n${GREEN}Step 14: Creating Deployment Information${NC}"
echo -e "${YELLOW}Writing deployment information...${NC}"
cat > $APP_DIR/DEPLOYMENT_INFO.txt << EOF
SolvIT Django Ticketing System - Deployment Information
=======================================================

Deployment Date: $(date)
Application Directory: $APP_DIR
Server IP: $SERVER_IP
Domain: $DOMAIN

Database:
- Name: $DB_NAME
- User: $DB_USER
- Password: $DB_PASSWORD

Django Admin:
- Username: $ADMIN_USER
- Password: $ADMIN_PASSWORD
- URL: http://$SERVER_IP:8001/admin/ or http://$DOMAIN/admin/

Services:
- Gunicorn: systemctl status solvit-ticketing
- Nginx: systemctl status nginx

Firewall:
- SSH, HTTP, HTTPS, and port 8001 are open
- Configured with fail2ban for protection

Logs:
- Application: journalctl -u solvit-ticketing
- Nginx access: /var/log/nginx/solvit-access.log
- Nginx error: /var/log/nginx/solvit-error.log
EOF

# Display summary
echo -e "\n${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     SolvIT Ticketing System - Deployment Complete   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo -e "${BLUE}Your SolvIT Ticketing System has been deployed successfully!${NC}"
echo -e "${BLUE}Server IP: ${NC}$SERVER_IP"
echo -e "${BLUE}Domain: ${NC}$DOMAIN"
echo -e "${BLUE}Admin URL: ${NC}http://$SERVER_IP:8001/admin/ or http://$DOMAIN/admin/"
echo -e "${BLUE}Admin Username: ${NC}$ADMIN_USER"
echo -e "${BLUE}Admin Password: ${NC}$ADMIN_PASSWORD"
echo -e "${BLUE}Deployment Info: ${NC}$APP_DIR/DEPLOYMENT_INFO.txt"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Make sure your domain points to this server's IP ($SERVER_IP)"
echo "2. Visit your site at http://$DOMAIN or https://$DOMAIN (if SSL is set up)"
echo "3. Log in with the admin credentials to verify everything works"
echo ""
echo -e "${GREEN}Thank you for using SolvIT Ticketing System!${NC}"
