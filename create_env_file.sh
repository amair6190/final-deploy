#!/bin/bash

# SolvIT Ticketing System - Environment File Creator
# This script creates a complete .env file with all required variables for production

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    SolvIT Ticketing System - Environment Setup   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"

# Get application directory
APP_DIR="/opt/solvit-ticketing"
if [ ! -d "$APP_DIR" ]; then
    echo -e "${YELLOW}Application directory $APP_DIR does not exist.${NC}"
    read -p "Enter the path to your SolvIT application directory: " APP_DIR
    if [ ! -d "$APP_DIR" ]; then
        echo -e "${RED}Directory $APP_DIR does not exist. Creating it...${NC}"
        mkdir -p "$APP_DIR"
    fi
fi

# Check if .env file exists and ask for backup
ENV_FILE="$APP_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}Found existing .env file.${NC}"
    read -p "Do you want to create a backup before proceeding? (y/n): " CREATE_BACKUP
    if [[ "$CREATE_BACKUP" == "y" || "$CREATE_BACKUP" == "Y" ]]; then
        BACKUP_FILE="$ENV_FILE.backup.$(date +%Y%m%d%H%M%S)"
        cp "$ENV_FILE" "$BACKUP_FILE"
        echo -e "${GREEN}Backup created at $BACKUP_FILE${NC}"
    fi
fi

# Database info
echo -e "\n${BLUE}Database Configuration${NC}"
read -p "Database Name [solvit_ticketing]: " DB_NAME
DB_NAME=${DB_NAME:-solvit_ticketing}

read -p "Database User [solvit]: " DB_USER
DB_USER=${DB_USER:-solvit}

read -s -p "Database Password [solvitpass]: " DB_PASSWORD
DB_PASSWORD=${DB_PASSWORD:-solvitpass}
echo

read -p "Database Host [localhost]: " DB_HOST
DB_HOST=${DB_HOST:-localhost}

read -p "Database Port [5432]: " DB_PORT
DB_PORT=${DB_PORT:-5432}

# Server configuration
echo -e "\n${BLUE}Server Configuration${NC}"
read -p "Server IP [10.0.0.18]: " SERVER_IP
SERVER_IP=${SERVER_IP:-10.0.0.18}

read -p "Domain Name [support.solvitservices.com]: " DOMAIN
DOMAIN=${DOMAIN:-support.solvitservices.com}

# Generate secret key if not provided
DJANGO_SECRET_KEY=$(python -c 'import random; import string; print("".join([random.choice(string.ascii_letters + string.digits + string.punctuation) for _ in range(50)]))')

# Create the .env file
cat > "$ENV_FILE" << EOF
# SolvIT Ticketing System Environment Variables
# Created by create_env_file.sh on $(date)

# Database Configuration
DB_ENGINE=django.db.backends.postgresql
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT

# Alternative database URL format (both formats are provided for compatibility)
DATABASE_URL=postgres://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME

# Django Configuration
DEBUG=False
SECRET_KEY=$DJANGO_SECRET_KEY
ALLOWED_HOSTS=127.0.0.1,localhost,$SERVER_IP,$DOMAIN,www.$DOMAIN

# SSL and Security
SECURE_SSL_REDIRECT=False
SECURE_HSTS_SECONDS=0
SECURE_HSTS_INCLUDE_SUBDOMAINS=False
SECURE_HSTS_PRELOAD=False

# CSRF Configuration
CSRF_TRUSTED_ORIGINS=http://127.0.0.1:8001,http://$SERVER_IP:8001,https://$DOMAIN,http://$DOMAIN,https://www.$DOMAIN,http://www.$DOMAIN

# File Upload Settings
MAX_UPLOAD_SIZE=5242880  # 5MB

# Admin URL (customize if needed)
ADMIN_URL=admin/
EOF

# Set proper permissions
echo -e "\n${BLUE}Setting File Permissions${NC}"

if id "solvit" &>/dev/null; then
    # If solvit user exists, make them the owner
    chown solvit:solvit "$ENV_FILE" 2>/dev/null || echo -e "${YELLOW}Could not change file ownership to solvit user.${NC}"
fi

chmod 600 "$ENV_FILE" 2>/dev/null || echo -e "${YELLOW}Could not set file permissions.${NC}"

echo -e "\n${GREEN}Environment file created successfully at:${NC} $ENV_FILE"
echo -e "${YELLOW}Remember to restart your application after changing environment variables:${NC}"
echo -e "  sudo systemctl restart solvit-ticketing"
echo -e "  sudo systemctl restart nginx"
