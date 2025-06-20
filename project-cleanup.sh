#!/bin/bash

# SolvIT Django Ticketing System - Project Cleanup Script
# This script removes unnecessary files while keeping the core project intact

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 SolvIT Django Ticketing System - Project Cleanup${NC}"
echo "====================================================="

# Ask confirmation
echo -e "${YELLOW}⚠️ WARNING: This will remove unnecessary files from your project.${NC}"
echo -e "${YELLOW}Essential files and directories for the core application will be kept.${NC}"
echo ""
read -p "Continue with cleanup? (y/n): " confirm
if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo -e "${RED}Cleanup aborted.${NC}"
    exit 0
fi

# Define essential files/directories to keep
ESSENTIAL_FILES=(
    "deploy-ubuntu-server.sh"
    "uninstall-solvit-ticketing.sh"
    "manage.py"
    "requirements.txt"
    "requirements_core.txt"
    "README.md"
    "jazzmin_settings.py"
    "updated-solvit-ticketing.service"
    "verify_domain_setup.sh"
    "post_deploy_verify.sh"
)

ESSENTIAL_DIRS=(
    "it_ticketing_system"
    "tickets"
    "templates"
    "static"
)

# Count files before cleanup
total_files_before=$(find . -type f | wc -l)
total_dirs_before=$(find . -type d | wc -l)

echo ""
echo -e "${GREEN}🔍 Starting cleanup process...${NC}"

# Remove all .md files except README.md
echo "Removing unnecessary documentation files..."
find . -name "*.md" ! -name "README.md" -type f -delete

# Remove all shell scripts except the essential ones
echo "Removing unnecessary shell scripts..."
find . -name "*.sh" ! -name "deploy-ubuntu-server.sh" ! -name "uninstall-solvit-ticketing.sh" ! -name "project-cleanup.sh" ! -name "verify_domain_setup.sh" ! -name "post_deploy_verify.sh" -type f -delete

# Remove nginx configuration files except the ones actually needed
echo "Removing old configuration files..."
find . -name "*.conf" -type f -delete

# Remove temp/test files
echo "Removing temporary and test files..."
find . -name "*.tmp" -o -name "*.bak" -o -name "*.test" -type f -delete

# Count files after cleanup
total_files_after=$(find . -type f | wc -l)
total_dirs_after=$(find . -type d | wc -l)

# Calculate difference
files_removed=$((total_files_before - total_files_after))
dirs_removed=$((total_dirs_before - total_dirs_after))

echo ""
echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo "---------------------------------------------------"
echo -e "Files removed: ${YELLOW}$files_removed${NC}"
echo -e "Directories removed: ${YELLOW}$dirs_removed${NC}"
echo "---------------------------------------------------"
echo ""
echo -e "${BLUE}📋 Essential files kept:${NC}"
for file in "${ESSENTIAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  - $file"
    fi
done

echo ""
echo -e "${BLUE}📁 Essential directories kept:${NC}"
for dir in "${ESSENTIAL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "  - $dir/"
    fi
done

echo ""
echo -e "${GREEN}🎯 Your project is now clean and ready for deployment!${NC}"
echo -e "${YELLOW}Run: sudo ./deploy-ubuntu-server.sh${NC}"

# Create verification scripts if they don't exist
if [ ! -f "verify_domain_setup.sh" ]; then
    echo "Recreating verify_domain_setup.sh script..."
    cat > verify_domain_setup.sh << 'EOF'
#!/bin/bash

# SolvIT Django Ticketing System - Domain Setup Verification Script
# This script verifies that your domain is properly configured

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 SolvIT Domain Setup Verification${NC}"
echo "====================================================="

# Ask for the domain name
read -p "Enter your domain name (e.g., ticketing.example.com): " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    echo -e "${RED}Error: Domain name cannot be empty.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Performing DNS lookup for $DOMAIN_NAME...${NC}"
IP_ADDRESS=$(dig +short $DOMAIN_NAME)

if [ -z "$IP_ADDRESS" ]; then
    echo -e "${RED}❌ DNS lookup failed. The domain $DOMAIN_NAME does not resolve to any IP address.${NC}"
    echo -e "${YELLOW}Please check your DNS configuration and ensure the domain is properly set up.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ DNS lookup successful! $DOMAIN_NAME resolves to: $IP_ADDRESS${NC}"
fi

# Get the server's public IP address
echo -e "\n${YELLOW}Checking this server's public IP address...${NC}"
SERVER_IP=$(curl -s https://api.ipify.org)

if [ "$IP_ADDRESS" = "$SERVER_IP" ]; then
    echo -e "${GREEN}✅ Domain points to this server's IP address! ($SERVER_IP)${NC}"
else
    echo -e "${RED}❌ Domain points to $IP_ADDRESS, but this server's IP is $SERVER_IP${NC}"
    echo -e "${YELLOW}Please update your DNS records to point to this server's IP address.${NC}"
fi

# Check if Nginx is running
echo -e "\n${YELLOW}Checking if Nginx is running...${NC}"
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Nginx is running${NC}"
    
    # Check if Nginx configuration exists for the domain
    if [ -f "/etc/nginx/sites-available/$DOMAIN_NAME" ]; then
        echo -e "${GREEN}✅ Nginx configuration found for $DOMAIN_NAME${NC}"
    else
        echo -e "${RED}❌ No Nginx configuration found for $DOMAIN_NAME${NC}"
        echo -e "${YELLOW}Please make sure the configuration is created at /etc/nginx/sites-available/$DOMAIN_NAME${NC}"
    fi
    
    # Check if the configuration is enabled
    if [ -L "/etc/nginx/sites-enabled/$DOMAIN_NAME" ]; then
        echo -e "${GREEN}✅ Nginx configuration is enabled${NC}"
    else
        echo -e "${RED}❌ Nginx configuration is not enabled${NC}"
        echo -e "${YELLOW}Run: sudo ln -s /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/${NC}"
    fi
else
    echo -e "${RED}❌ Nginx is not running${NC}"
    echo -e "${YELLOW}Run: sudo systemctl start nginx${NC}"
fi

# Check if SSL is configured (if a certificate exists)
echo -e "\n${YELLOW}Checking SSL configuration...${NC}"
if [ -d "/etc/letsencrypt/live/$DOMAIN_NAME" ]; then
    echo -e "${GREEN}✅ SSL certificate found for $DOMAIN_NAME${NC}"
    
    # Check certificate expiration
    EXPIRATION=$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/$DOMAIN_NAME/cert.pem | cut -d= -f2)
    echo -e "${GREEN}   Certificate expires: $EXPIRATION${NC}"
else
    echo -e "${YELLOW}⚠️ No SSL certificate found for $DOMAIN_NAME${NC}"
    echo -e "${YELLOW}To obtain an SSL certificate, run:${NC}"
    echo -e "${YELLOW}sudo certbot --nginx -d $DOMAIN_NAME${NC}"
fi

echo -e "\n${BLUE}==== Verification Summary ====${NC}"
echo -e "Domain Name: $DOMAIN_NAME"
echo -e "Resolves to IP: $IP_ADDRESS"
echo -e "Server IP: $SERVER_IP"
echo -e "\n${GREEN}✅ Verification complete!${NC}"
EOF
    chmod +x verify_domain_setup.sh
fi

if [ ! -f "post_deploy_verify.sh" ]; then
    echo "Recreating post_deploy_verify.sh script..."
    cat > post_deploy_verify.sh << 'EOF'
#!/bin/bash

# SolvIT Django Ticketing System - Post Deployment Verification Script
# This script checks that your SolvIT Ticketing System is properly deployed

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 SolvIT Post Deployment Verification${NC}"
echo "====================================================="

# Check Python and virtual environment
echo -e "\n${YELLOW}Checking Python environment...${NC}"
if [ -d "/opt/solvit/venv" ]; then
    echo -e "${GREEN}✅ Virtual environment exists at /opt/solvit/venv${NC}"
    
    # Check Python version in venv
    PYTHON_VERSION=$(/opt/solvit/venv/bin/python3 --version)
    echo -e "${GREEN}✅ $PYTHON_VERSION is installed${NC}"
    
    # Check Django version
    DJANGO_VERSION=$(/opt/solvit/venv/bin/pip show Django | grep Version)
    echo -e "${GREEN}✅ Django $DJANGO_VERSION${NC}"
else
    echo -e "${RED}❌ Virtual environment not found at /opt/solvit/venv${NC}"
fi

# Check PostgreSQL
echo -e "\n${YELLOW}Checking PostgreSQL...${NC}"
if systemctl is-active --quiet postgresql; then
    echo -e "${GREEN}✅ PostgreSQL is running${NC}"
    
    # Check if we can connect to PostgreSQL
    if sudo -u postgres psql -c '\l' | grep -q "solvit"; then
        echo -e "${GREEN}✅ SolvIT database exists${NC}"
    else
        echo -e "${RED}❌ SolvIT database not found${NC}"
    fi
else
    echo -e "${RED}❌ PostgreSQL is not running${NC}"
fi

# Check system services
echo -e "\n${YELLOW}Checking system services...${NC}"

# Check Gunicorn service
if systemctl is-active --quiet solvit-ticketing.service; then
    echo -e "${GREEN}✅ Gunicorn service is running${NC}"
else
    echo -e "${RED}❌ Gunicorn service is not running${NC}"
    echo -e "${YELLOW}   Run: sudo systemctl start solvit-ticketing.service${NC}"
fi

# Check Nginx service
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Nginx service is running${NC}"
else
    echo -e "${RED}❌ Nginx service is not running${NC}"
    echo -e "${YELLOW}   Run: sudo systemctl start nginx${NC}"
fi

# Check application files
echo -e "\n${YELLOW}Checking application files...${NC}"
if [ -f "/opt/solvit/manage.py" ]; then
    echo -e "${GREEN}✅ Django application files exist${NC}"
else
    echo -e "${RED}❌ Django application files not found${NC}"
fi

# Check static files
if [ -d "/opt/solvit/staticfiles" ]; then
    echo -e "${GREEN}✅ Static files are collected${NC}"
else
    echo -e "${RED}❌ Static files directory not found${NC}"
    echo -e "${YELLOW}   Run: cd /opt/solvit && ./venv/bin/python manage.py collectstatic --noinput${NC}"
fi

# Check if the site is accessible locally
echo -e "\n${YELLOW}Checking local site access...${NC}"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ]; then
    echo -e "${GREEN}✅ Site is accessible locally (Status: $HTTP_STATUS)${NC}"
else
    echo -e "${RED}❌ Site is not accessible locally (Status: $HTTP_STATUS)${NC}"
fi

echo -e "\n${BLUE}==== Verification Summary ====${NC}"
echo -e "Environment: $([[ -d "/opt/solvit/venv" ]] && echo "${GREEN}✅" || echo "${RED}❌")"
echo -e "Database: $([[ $(sudo -u postgres psql -c '\l' | grep -q "solvit") == 0 ]] && echo "${GREEN}✅" || echo "${RED}❌")"
echo -e "Gunicorn: $([[ $(systemctl is-active solvit-ticketing.service) == "active" ]] && echo "${GREEN}✅" || echo "${RED}❌")"
echo -e "Nginx: $([[ $(systemctl is-active nginx) == "active" ]] && echo "${GREEN}✅" || echo "${RED}❌")"
echo -e "Local Access: $([[ "$HTTP_STATUS" = "200" || "$HTTP_STATUS" = "302" ]] && echo "${GREEN}✅" || echo "${RED}❌")"

echo -e "\n${GREEN}✅ Verification complete!${NC}"
EOF
    chmod +x post_deploy_verify.sh
fi
