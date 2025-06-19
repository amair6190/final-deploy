#!/bin/bash

# SolvIT Ticketing System - Post-Deployment Verification
# This script verifies and fixes common deployment issues

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   SolvIT Ticketing System - Deploy Verification  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"

# Check if running with sudo/root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root or with sudo privileges${NC}"
    exit 1
fi

# Application directory
APP_DIR="/opt/solvit-ticketing"
if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}Error: Application directory not found: $APP_DIR${NC}"
    exit 1
fi

# Function to display section headers
section() {
    echo -e "\n${YELLOW}$1${NC}"
}

# Function to verify a command result
verify() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Success: $1${NC}"
    else
        echo -e "${RED}✗ Failed: $1${NC}"
        if [ -n "$2" ]; then
            echo -e "${CYAN}Suggestion: $2${NC}"
        fi
    fi
}

# 1. Check Environment Variables
section "1. Checking Environment Variables"
ENV_FILE="$APP_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}✓ .env file found${NC}"
    
    # Check for essential variables
    essential_vars=("DB_NAME" "DB_USER" "DB_PASSWORD" "SECRET_KEY" "ALLOWED_HOSTS")
    missing_vars=()
    
    for var in "${essential_vars[@]}"; do
        if ! grep -q "^$var=" "$ENV_FILE"; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ All essential environment variables are present${NC}"
    else
        echo -e "${RED}✗ Missing essential environment variables: ${missing_vars[*]}${NC}"
        echo -e "${CYAN}Suggestion: Run the create_env_file.sh script to create a complete .env file${NC}"
    fi
else
    echo -e "${RED}✗ .env file not found${NC}"
    echo -e "${CYAN}Suggestion: Create a .env file with required variables${NC}"
    echo -e "${CYAN}  Run ./create_env_file.sh to create it automatically${NC}"
    
    # Create a minimal .env file for emergency
    read -p "Do you want to create a minimal .env file now? (y/n): " CREATE_ENV
    if [[ "$CREATE_ENV" == "y" || "$CREATE_ENV" == "Y" ]]; then
        cat > "$ENV_FILE" << EOF
# SolvIT Ticketing System Minimal Environment Variables
# Created by post_deploy_verify.sh on $(date)

# Database Configuration
DB_NAME=solvit_ticketing
DB_USER=solvit
DB_PASSWORD=solvitpass
DB_HOST=localhost
DB_PORT=5432
DATABASE_URL=postgres://solvit:solvitpass@localhost:5432/solvit_ticketing

# Django Configuration
DEBUG=False
SECRET_KEY=$(python -c 'import random; import string; print("".join([random.choice(string.ascii_letters + string.digits) for _ in range(50)]))')
ALLOWED_HOSTS=127.0.0.1,localhost,10.0.0.18,support.solvitservices.com
CSRF_TRUSTED_ORIGINS=http://127.0.0.1:8001,http://10.0.0.18:8001,https://support.solvitservices.com,http://support.solvitservices.com
EOF
        chmod 600 "$ENV_FILE"
        if id "solvit" &>/dev/null; then
            chown solvit:solvit "$ENV_FILE"
        fi
        echo -e "${GREEN}✓ Minimal .env file created${NC}"
    fi
fi

# 2. Check Database
section "2. Checking Database"
if command -v psql &> /dev/null; then
    echo -e "${GREEN}✓ PostgreSQL client installed${NC}"
    
    # Check if PostgreSQL is running
    if systemctl is-active --quiet postgresql; then
        echo -e "${GREEN}✓ PostgreSQL service is running${NC}"
        
        # Get database name from .env
        if [ -f "$ENV_FILE" ]; then
            DB_NAME=$(grep -E "^DB_NAME=" "$ENV_FILE" | cut -d= -f2)
            DB_USER=$(grep -E "^DB_USER=" "$ENV_FILE" | cut -d= -f2)
            
            # Check if database exists
            if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
                echo -e "${GREEN}✓ Database '$DB_NAME' exists${NC}"
            else
                echo -e "${RED}✗ Database '$DB_NAME' does not exist${NC}"
                echo -e "${CYAN}Suggestion: Create the database${NC}"
                
                read -p "Do you want to create the database now? (y/n): " CREATE_DB
                if [[ "$CREATE_DB" == "y" || "$CREATE_DB" == "Y" ]]; then
                    sudo -u postgres createdb "$DB_NAME"
                    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD 'solvitpass';" 2>/dev/null || echo -e "${YELLOW}Note: User may already exist${NC}"
                    sudo -u postgres psql -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';"
                    sudo -u postgres psql -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';"
                    sudo -u postgres psql -c "ALTER ROLE $DB_USER SET timezone TO 'UTC';"
                    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
                    verify "Database created and permissions set" 
                fi
            fi
        else
            echo -e "${YELLOW}⚠ Cannot determine database name without .env file${NC}"
        fi
    else
        echo -e "${RED}✗ PostgreSQL service is not running${NC}"
        echo -e "${CYAN}Suggestion: Start PostgreSQL service${NC}"
        
        read -p "Do you want to start PostgreSQL now? (y/n): " START_PG
        if [[ "$START_PG" == "y" || "$START_PG" == "Y" ]]; then
            systemctl start postgresql
            verify "Started PostgreSQL service"
        fi
    fi
else
    echo -e "${RED}✗ PostgreSQL client not installed${NC}"
    echo -e "${CYAN}Suggestion: Install PostgreSQL${NC}"
    
    read -p "Do you want to install PostgreSQL now? (y/n): " INSTALL_PG
    if [[ "$INSTALL_PG" == "y" || "$INSTALL_PG" == "Y" ]]; then
        apt-get update
        apt-get install -y postgresql postgresql-contrib
        verify "Installed PostgreSQL"
        systemctl start postgresql
        verify "Started PostgreSQL service"
    fi
fi

# 3. Check Python Environment
section "3. Checking Python Environment"
VENV_DIR="$APP_DIR/venv"
if [ -d "$VENV_DIR" ]; then
    echo -e "${GREEN}✓ Python virtual environment exists${NC}"
    
    # Check for critical packages
    if [ -f "$VENV_DIR/bin/pip" ]; then
        echo -e "${YELLOW}Checking for required Python packages...${NC}"
        
        required_packages=("django" "psycopg2" "django-environ" "gunicorn" "dj-database-url")
        missing_packages=()
        
        for pkg in "${required_packages[@]}"; do
            if ! sudo -u solvit bash -c "cd $APP_DIR && source $VENV_DIR/bin/activate && pip freeze | grep -i $pkg" &>/dev/null; then
                missing_packages+=("$pkg")
            fi
        done
        
        if [ ${#missing_packages[@]} -eq 0 ]; then
            echo -e "${GREEN}✓ All essential Python packages are installed${NC}"
        else
            echo -e "${RED}✗ Missing essential Python packages: ${missing_packages[*]}${NC}"
            
            read -p "Do you want to install the missing packages now? (y/n): " INSTALL_PKGS
            if [[ "$INSTALL_PKGS" == "y" || "$INSTALL_PKGS" == "Y" ]]; then
                for pkg in "${missing_packages[@]}"; do
                    sudo -u solvit bash -c "cd $APP_DIR && source $VENV_DIR/bin/activate && pip install $pkg"
                    verify "Installed $pkg"
                done
            fi
        fi
    else
        echo -e "${RED}✗ Virtual environment appears to be corrupt${NC}"
        echo -e "${CYAN}Suggestion: Recreate the virtual environment${NC}"
        
        read -p "Do you want to recreate the virtual environment now? (y/n): " RECREATE_VENV
        if [[ "$RECREATE_VENV" == "y" || "$RECREATE_VENV" == "Y" ]]; then
            rm -rf "$VENV_DIR"
            sudo -u solvit bash -c "cd $APP_DIR && python3 -m venv venv"
            sudo -u solvit bash -c "cd $APP_DIR && source venv/bin/activate && pip install -r requirements.txt"
            verify "Recreated virtual environment and installed requirements"
        fi
    fi
else
    echo -e "${RED}✗ Python virtual environment not found${NC}"
    echo -e "${CYAN}Suggestion: Create the virtual environment and install requirements${NC}"
    
    read -p "Do you want to create the virtual environment now? (y/n): " CREATE_VENV
    if [[ "$CREATE_VENV" == "y" || "$CREATE_VENV" == "Y" ]]; then
        sudo -u solvit bash -c "cd $APP_DIR && python3 -m venv venv"
        sudo -u solvit bash -c "cd $APP_DIR && source venv/bin/activate && pip install -r requirements.txt"
        verify "Created virtual environment and installed requirements"
    fi
fi

# 4. Check Services
section "4. Checking Services"
# Check Gunicorn service
if [ -f "/etc/systemd/system/solvit-ticketing.service" ]; then
    echo -e "${GREEN}✓ Gunicorn service file exists${NC}"
    
    # Check if service is running
    if systemctl is-active --quiet solvit-ticketing; then
        echo -e "${GREEN}✓ Gunicorn service is running${NC}"
    else
        echo -e "${RED}✗ Gunicorn service is not running${NC}"
        
        # Check service configuration for common issues - ALWAYS fix binding issues
        if grep -q "bind 127.0.0.1:8001" /etc/systemd/system/solvit-ticketing.service; then
            echo -e "${YELLOW}⚠ Gunicorn is configured to bind only to localhost (127.0.0.1)${NC}"
            echo -e "${GREEN}Automatically updating bind address to 0.0.0.0:8001 to prevent connection issues${NC}"
            
            # Fix the binding without asking
            sed -i 's/--bind 127.0.0.1:8001/--bind 0.0.0.0:8001/g' /etc/systemd/system/solvit-ticketing.service
            systemctl daemon-reload
            verify "Updated bind address to 0.0.0.0:8001"
        fi
        
        # Try to start the service
        read -p "Do you want to start the Gunicorn service now? (y/n): " START_GUNICORN
        if [[ "$START_GUNICORN" == "y" || "$START_GUNICORN" == "Y" ]]; then
            systemctl restart solvit-ticketing
            verify "Started Gunicorn service" "Check logs: journalctl -u solvit-ticketing"
        fi
    fi
else
    echo -e "${RED}✗ Gunicorn service file not found${NC}"
    echo -e "${CYAN}Suggestion: Create the Gunicorn service file${NC}"
    
    read -p "Do you want to create the service file now? (y/n): " CREATE_SERVICE
    if [[ "$CREATE_SERVICE" == "y" || "$CREATE_SERVICE" == "Y" ]]; then
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
WorkingDirectory=/opt/solvit-ticketing
Environment="PATH=/opt/solvit-ticketing/venv/bin"
Environment="DJANGO_SETTINGS_MODULE=it_ticketing_system.settings_production"
ExecStart=/opt/solvit-ticketing/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:8001 --timeout 60 --keep-alive 2 --max-requests 1000 it_ticketing_system.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable solvit-ticketing
        systemctl start solvit-ticketing
        verify "Created and started Gunicorn service"
    fi
fi

# Check Nginx service
if [ -f "/etc/nginx/sites-available/solvit" ]; then
    echo -e "${GREEN}✓ Nginx site configuration exists${NC}"
    
    # Check if linked in sites-enabled
    if [ ! -f "/etc/nginx/sites-enabled/solvit" ]; then
        echo -e "${YELLOW}⚠ Nginx site is not enabled${NC}"
        echo -e "${CYAN}Suggestion: Create symlink in sites-enabled${NC}"
        
        read -p "Do you want to enable the site now? (y/n): " ENABLE_SITE
        if [[ "$ENABLE_SITE" == "y" || "$ENABLE_SITE" == "Y" ]]; then
            ln -sf /etc/nginx/sites-available/solvit /etc/nginx/sites-enabled/
            verify "Enabled Nginx site"
        fi
    fi
    
    # Check if Nginx is running
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓ Nginx service is running${NC}"
    else
        echo -e "${RED}✗ Nginx service is not running${NC}"
        echo -e "${CYAN}Suggestion: Start Nginx service${NC}"
        
        read -p "Do you want to start Nginx now? (y/n): " START_NGINX
        if [[ "$START_NGINX" == "y" || "$START_NGINX" == "Y" ]]; then
            systemctl start nginx
            verify "Started Nginx service"
        fi
    fi
else
    echo -e "${RED}✗ Nginx site configuration not found${NC}"
    echo -e "${CYAN}Suggestion: Create the Nginx site configuration${NC}"
    
    read -p "Do you want to create the site configuration now? (y/n): " CREATE_NGINX
    if [[ "$CREATE_NGINX" == "y" || "$CREATE_NGINX" == "Y" ]]; then
        cat > /etc/nginx/sites-available/solvit << EOF
server {
    listen 80;
    server_name _;  # Catch all incoming requests

    location /static/ {
        alias /opt/solvit-ticketing/staticfiles/;
    }

    location /media/ {
        alias /opt/solvit-ticketing/media/;
    }

    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://127.0.0.1:8001;
    }
}
EOF
        ln -sf /etc/nginx/sites-available/solvit /etc/nginx/sites-enabled/
        systemctl restart nginx
        verify "Created and enabled Nginx site configuration"
    fi
fi

# 5. Check Firewall
section "5. Checking Firewall"
if command -v ufw &> /dev/null; then
    echo -e "${GREEN}✓ UFW firewall is installed${NC}"
    
    # Check if firewall is active
    if ufw status | grep -q "Status: active"; then
        echo -e "${GREEN}✓ Firewall is active${NC}"
        
        # Check for required rules
        if ! ufw status | grep -q "8001/tcp"; then
            echo -e "${YELLOW}⚠ No firewall rule for port 8001${NC}"
            echo -e "${CYAN}Suggestion: Allow access to port 8001${NC}"
            
            read -p "Do you want to add a rule for port 8001 now? (y/n): " ADD_RULE
            if [[ "$ADD_RULE" == "y" || "$ADD_RULE" == "Y" ]]; then
                ufw allow 8001/tcp comment "SolvIT Django App"
                verify "Added firewall rule for port 8001"
            fi
        else
            echo -e "${GREEN}✓ Firewall rule for port 8001 exists${NC}"
        fi
        
        if ! ufw status | grep -q "80/tcp"; then
            echo -e "${YELLOW}⚠ No firewall rule for port 80${NC}"
            echo -e "${CYAN}Suggestion: Allow access to port 80${NC}"
            
            read -p "Do you want to add a rule for port 80 now? (y/n): " ADD_RULE
            if [[ "$ADD_RULE" == "y" || "$ADD_RULE" == "Y" ]]; then
                ufw allow 80/tcp comment "HTTP"
                verify "Added firewall rule for port 80"
            fi
        else
            echo -e "${GREEN}✓ Firewall rule for port 80 exists${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Firewall is not active${NC}"
        echo -e "${CYAN}Suggestion: Enable the firewall${NC}"
        
        read -p "Do you want to enable the firewall now? (y/n): " ENABLE_UFW
        if [[ "$ENABLE_UFW" == "y" || "$ENABLE_UFW" == "Y" ]]; then
            # First, ensure SSH access is allowed to prevent lockout
            ufw allow OpenSSH
            ufw allow 80/tcp comment "HTTP"
            ufw allow 8001/tcp comment "SolvIT Django App"
            echo "y" | ufw enable
            verify "Enabled firewall with required rules"
        fi
    fi
else
    echo -e "${YELLOW}⚠ UFW firewall is not installed${NC}"
    echo -e "${CYAN}Suggestion: Install UFW firewall${NC}"
    
    read -p "Do you want to install UFW now? (y/n): " INSTALL_UFW
    if [[ "$INSTALL_UFW" == "y" || "$INSTALL_UFW" == "Y" ]]; then
        apt-get update
        apt-get install -y ufw
        verify "Installed UFW firewall"
    fi
fi

# 6. Run Django Migrations and Collect Static
section "6. Checking Django Setup"
if [ -d "$APP_DIR" ]; then
    # Check if app has been migrated
    read -p "Do you want to run Django migrations? (y/n): " RUN_MIGRATIONS
    if [[ "$RUN_MIGRATIONS" == "y" || "$RUN_MIGRATIONS" == "Y" ]]; then
        sudo -u solvit bash -c "cd $APP_DIR && source venv/bin/activate && DJANGO_SETTINGS_MODULE=it_ticketing_system.settings_production python manage.py migrate"
        verify "Applied database migrations"
    fi
    
    # Check if static files have been collected
    read -p "Do you want to collect static files? (y/n): " COLLECT_STATIC
    if [[ "$COLLECT_STATIC" == "y" || "$COLLECT_STATIC" == "Y" ]]; then
        sudo -u solvit bash -c "cd $APP_DIR && source venv/bin/activate && DJANGO_SETTINGS_MODULE=it_ticketing_system.settings_production python manage.py collectstatic --noinput"
        verify "Collected static files"
    fi
fi

# 7. Test Connectivity
section "7. Testing Connectivity"
echo -e "${YELLOW}Testing connection to Gunicorn (port 8001)...${NC}"
curl -I http://localhost:8001 || echo -e "${RED}Failed to connect to Gunicorn${NC}"

echo -e "\n${YELLOW}Testing connection to Nginx (port 80)...${NC}"
curl -I http://localhost || echo -e "${RED}Failed to connect to Nginx${NC}"

echo -e "\n${BLUE}===========================================${NC}"
echo -e "${BLUE}SolvIT Ticketing System Verification Complete${NC}"
echo -e "${BLUE}===========================================${NC}"

# Restart services as final step
read -p "Do you want to restart all services to apply changes? (y/n): " RESTART_ALL
if [[ "$RESTART_ALL" == "y" || "$RESTART_ALL" == "Y" ]]; then
    systemctl restart postgresql
    systemctl restart solvit-ticketing
    systemctl restart nginx
    echo -e "${GREEN}All services restarted${NC}"
fi

echo -e "\n${YELLOW}Your SolvIT Ticketing System should now be accessible at:${NC}"
echo -e "${CYAN}  http://$(hostname -I | awk '{print $1}'):8001${NC} (direct to Gunicorn)"
echo -e "${CYAN}  http://$(hostname -I | awk '{print $1}')${NC} (via Nginx)"
