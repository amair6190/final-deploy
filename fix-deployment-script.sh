#!/bin/bash

# Quick fix for the deployment script
# Run this on your Ubuntu server to update the deploy-http-only.sh script

echo "🔧 Fixing Django Ticketing System deployment script..."

# Download the fixed script content
cat > deploy-http-only-fixed.sh << 'EOF'
#!/bin/bash

# Django Ticketing System - Complete HTTP-Only Deployment Script
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
    echo -e "${CYAN}║${BOLD}                    HTTP-Only Version                         ${NC}${CYAN}║${NC}"
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

# Create log file
mkdir -p $(dirname "$LOG_FILE")
touch "$LOG_FILE"

# Function to log commands
log_command() {
    echo "$(date): $1" >> "$LOG_FILE"
    eval "$1" 2>&1 | tee -a "$LOG_FILE"
}

# Collect configuration
collect_config() {
    print_phase "CONFIGURATION SETUP"
    
    # Get server information
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
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
    cat > /tmp/deployment_config.env << EOF
DOMAIN="$DOMAIN"
SERVER_IP="$SERVER_IP"
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DB_PASSWORD="$DB_PASSWORD"
ADMIN_EMAIL="$ADMIN_EMAIL"
ADMIN_USER="$ADMIN_USER"
ADMIN_PASSWORD="$ADMIN_PASSWORD"
SECRET_KEY="$SECRET_KEY"
DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
EOF
    
    print_success "Configuration saved to /tmp/deployment_config.env"
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
    if netstat -tuln | grep -q ":80 "; then
        print_warning "Port 80 is already in use"
    else
        print_success "Port 80 is available"
    fi
    
    if netstat -tuln | grep -q ":5432 "; then
        print_warning "Port 5432 (PostgreSQL) is already in use"
    else
        print_success "Port 5432 is available"
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    print_success "Backup directory created: $BACKUP_DIR"
}

# Execute deployment phase
execute_phase() {
    local phase_name="$1"
    local script_name="$2"
    local description="$3"
    
    print_phase "$phase_name"
    print_status "$description"
    
    if [ ! -f "$script_name" ]; then
        print_error "Script not found: $script_name"
        exit 1
    fi
    
    chmod +x "$script_name"
    
    print_status "Executing: $script_name"
    log_command "bash $script_name"
    
    if [ $? -eq 0 ]; then
        print_success "$phase_name completed successfully"
    else
        print_error "$phase_name failed"
        print_error "Check log file: $LOG_FILE"
        exit 1
    fi
    
    echo ""
}

# Create Django superuser
create_superuser() {
    print_phase "CREATING DJANGO SUPERUSER"
    
    source /tmp/deployment_config.env
    
    cd "$DEPLOYMENT_DIR/app"
    
    # Create superuser script
    cat > create_superuser.py << EOF
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'it_ticketing_system.settings')
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
    sudo -u www-data python3 create_superuser.py
    rm create_superuser.py
    
    print_success "Django superuser created"
}

# Update Django secret key with proper Django key
update_django_secret_key() {
    print_phase "UPDATING DJANGO SECRET KEY"
    
    source /tmp/deployment_config.env
    
    cd "$DEPLOYMENT_DIR/app"
    
    # Generate proper Django secret key
    print_status "Generating proper Django secret key..."
    NEW_SECRET_KEY=$(sudo -u www-data python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")
    
    # Update the environment file
    sed -i "s|SECRET_KEY=\".*\"|SECRET_KEY=\"$NEW_SECRET_KEY\"|" /tmp/deployment_config.env
    
    print_success "Django secret key updated"
}

# Final configuration and testing
finalize_deployment() {
    print_phase "FINALIZING DEPLOYMENT"
    
    source /tmp/deployment_config.env
    
    # Collect static files
    print_status "Collecting static files..."
    cd "$DEPLOYMENT_DIR/app"
    sudo -u www-data python3 manage.py collectstatic --noinput
    
    # Test database connection
    print_status "Testing database connection..."
    sudo -u www-data python3 manage.py dbshell --command="\l" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "Database connection successful"
    else
        print_warning "Database connection test failed"
    fi
    
    # Test Django application
    print_status "Testing Django application..."
    sudo -u www-data python3 manage.py check --deploy
    
    # Set proper permissions
    print_status "Setting file permissions..."
    chown -R www-data:www-data "$DEPLOYMENT_DIR"
    chmod -R 755 "$DEPLOYMENT_DIR"
    chmod -R 644 "$DEPLOYMENT_DIR/app/media"
    
    # Create systemd service status check
    print_status "Checking services..."
    systemctl is-active --quiet postgresql && print_success "PostgreSQL: Running" || print_error "PostgreSQL: Not running"
    systemctl is-active --quiet gunicorn-django-ticketing && print_success "Gunicorn: Running" || print_error "Gunicorn: Not running"
    systemctl is-active --quiet nginx && print_success "Nginx: Running" || print_error "Nginx: Not running"
    
    print_success "Deployment finalized"
}

# Generate deployment report
generate_report() {
    print_phase "DEPLOYMENT REPORT"
    
    source /tmp/deployment_config.env
    
    REPORT_FILE="/opt/django-ticketing/DEPLOYMENT_REPORT.md"
    
    cat > "$REPORT_FILE" << EOF
# Django Ticketing System Deployment Report

**Deployment Date:** $(date)
**Server:** $HOSTNAME ($SERVER_IP)
**Deployment Type:** HTTP Only (No SSL)

## System Information
- **Operating System:** $(lsb_release -d | cut -f2)
- **Kernel:** $(uname -r)
- **Architecture:** $(uname -m)
- **Memory:** $(free -h | awk 'NR==2{print $2}')
- **Disk Space:** $(df -h / | awk 'NR==2{print $2}')

## Application Configuration
- **Domain:** $DOMAIN
- **Application Directory:** $DEPLOYMENT_DIR
- **Database:** PostgreSQL ($DB_NAME)
- **Web Server:** Nginx (HTTP Only)
- **Application Server:** Gunicorn
- **Admin User:** $ADMIN_USER
- **Admin Email:** $ADMIN_EMAIL

## Service Status
$(systemctl is-active postgresql && echo "- **PostgreSQL:** ✅ Running" || echo "- **PostgreSQL:** ❌ Not Running")
$(systemctl is-active gunicorn-django-ticketing && echo "- **Gunicorn:** ✅ Running" || echo "- **Gunicorn:** ❌ Not Running")
$(systemctl is-active nginx && echo "- **Nginx:** ✅ Running" || echo "- **Nginx:** ❌ Not Running")

## Access Information
- **Application URL:** http://$DOMAIN
- **Admin Panel:** http://$DOMAIN/admin/
- **Admin Username:** $ADMIN_USER

## Important Files
- **Application:** $DEPLOYMENT_DIR/app/
- **Static Files:** $DEPLOYMENT_DIR/app/static/
- **Media Files:** $DEPLOYMENT_DIR/app/media/
- **Logs:** /var/log/nginx/ and /var/log/django-ticketing/
- **Configuration:** /etc/nginx/sites-available/django-ticketing
- **Deployment Log:** $LOG_FILE

## Security Features
- ✅ Rate limiting for login attempts
- ✅ Security headers (except HSTS)
- ✅ File upload size limits (100MB)
- ✅ Attack pattern blocking
- ✅ Firewall configured (HTTP + SSH only)
- ❌ SSL/HTTPS (HTTP-only deployment)

## Post-Deployment Tasks
1. Test the application at http://$DOMAIN
2. Login to admin panel with provided credentials
3. Configure DNS if using custom domain
4. Set up regular backups
5. Monitor application logs
6. Consider enabling SSL for production use

## Backup Information
- **Backup Directory:** $BACKUP_DIR
- **Database Backup:** Use \`pg_dump $DB_NAME > backup.sql\`
- **Application Backup:** Use \`tar -czf app-backup.tar.gz $DEPLOYMENT_DIR\`

---
*This report was generated automatically during deployment.*
EOF

    print_success "Deployment report saved to: $REPORT_FILE"
}

# Display final summary
display_summary() {
    print_phase "DEPLOYMENT COMPLETE!"
    
    source /tmp/deployment_config.env
    
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
    echo -e "   → Logs: ${BOLD}/var/log/nginx/${NC}"
    echo -e "   → Report: ${BOLD}/opt/django-ticketing/DEPLOYMENT_REPORT.md${NC}"
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
    rm -f /tmp/deployment_config.env
    
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
    
    execute_phase "PHASE 1: SYSTEM SETUP" "./01-system-setup.sh" "Installing system dependencies and basic configuration"
    execute_phase "PHASE 2: DATABASE SETUP" "./02-postgresql-setup.sh" "Installing and configuring PostgreSQL database"
    execute_phase "PHASE 3: DJANGO APPLICATION SETUP" "./03-django-app-setup.sh" "Cloning and configuring Django application"
    update_django_secret_key
    execute_phase "PHASE 4: WEB SERVER SETUP (HTTP)" "./04-nginx-setup-no-ssl.sh" "Installing and configuring Nginx web server"
    execute_phase "PHASE 5: SECURITY HARDENING" "./05-security-hardening.sh" "Applying security configurations"
    
    create_superuser
    finalize_deployment
    generate_report
    display_summary
}

# Trap for cleanup on exit
cleanup() {
    if [ -f /tmp/deployment_config.env ]; then
        rm -f /tmp/deployment_config.env
    fi
}
trap cleanup EXIT

# Run main function
main "$@"
EOF

# Make the fixed script executable
chmod +x deploy-http-only-fixed.sh

# Replace the original script
mv deploy-http-only-fixed.sh deploy-http-only.sh

echo "✅ Deployment script has been fixed!"
echo ""
echo "🚀 Now you can run the deployment again with:"
echo "   sudo ./deploy-http-only.sh"
echo ""
echo "📋 The fix addresses:"
echo "   ✅ Django module import error during configuration"
echo "   ✅ Proper secret key generation after Django installation"
echo "   ✅ Enhanced error handling and logging"
EOF

chmod +x fix-deployment-script.sh

echo "🔧 Quick fix script created!"
echo ""
echo "📋 On your Ubuntu server, run these commands:"
echo ""
echo "# Navigate to your deployment directory"
echo "cd ~/solvit-django-ticketing-system/ubuntu-deployment"
echo ""
echo "# Run the fix script"
echo "./fix-deployment-script.sh"
echo ""
echo "# Then run the deployment again"
echo "sudo ./deploy-http-only.sh"
