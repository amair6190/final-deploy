#!/bin/bash

# SolvIT Django Ticketing System - Uninstall Script
# This script safely removes the deployed Django ticketing system

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to prompt for confirmation
confirm() {
    local message="$1"
    local response
    echo -e "${CYAN}$message${NC} (y/N): "
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root for safety reasons."
        error "Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Banner
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    SolvIT Ticketing System                   ║"
echo "║                     UNINSTALL SCRIPT                         ║"
echo "║                                                              ║"
echo "║          🗑️  Complete System Removal Tool 🗑️                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if running as root
check_root

# Default values
PROJECT_DIR="/opt/solvit-ticketing"
SERVICE_NAME="solvit-ticketing"
DB_NAME="test2"
DB_USER="test2"
NGINX_SITE="solvit-ticketing"

# Warning message
echo -e "${RED}⚠️  WARNING: This script will completely remove the SolvIT Ticketing System!${NC}"
echo ""
echo "The following will be PERMANENTLY DELETED:"
echo "• Application files in $PROJECT_DIR"
echo "• PostgreSQL database: $DB_NAME"
echo "• Database user: $DB_USER"
echo "• Systemd service: $SERVICE_NAME"
echo "• Nginx configuration (if exists)"
echo "• All static files and media uploads"
echo ""

if ! confirm "Are you absolutely sure you want to proceed with the uninstallation?"; then
    log "Uninstallation cancelled by user."
    exit 0
fi

echo ""
log "Starting SolvIT Ticketing System uninstallation..."

# 1. Stop and disable the systemd service
log "Stopping and disabling systemd service..."
if systemctl is-active --quiet "$SERVICE_NAME"; then
    sudo systemctl stop "$SERVICE_NAME"
    success "Service $SERVICE_NAME stopped"
else
    warning "Service $SERVICE_NAME was not running"
fi

if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    sudo systemctl disable "$SERVICE_NAME"
    success "Service $SERVICE_NAME disabled"
else
    warning "Service $SERVICE_NAME was not enabled"
fi

# 2. Remove systemd service file
log "Removing systemd service file..."
if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
    sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    sudo systemctl daemon-reload
    success "Service file removed"
else
    warning "Service file not found"
fi

# 3. Remove Nginx configuration (if exists)
log "Checking for Nginx configuration..."
if [ -f "/etc/nginx/sites-available/$NGINX_SITE" ]; then
    if confirm "Remove Nginx configuration for $NGINX_SITE?"; then
        sudo rm -f "/etc/nginx/sites-available/$NGINX_SITE"
        sudo rm -f "/etc/nginx/sites-enabled/$NGINX_SITE"
        sudo nginx -t && sudo systemctl reload nginx
        success "Nginx configuration removed"
    fi
else
    log "No Nginx configuration found"
fi

# 4. Database removal
log "Removing PostgreSQL database and user..."
if confirm "Remove database '$DB_NAME' and user '$DB_USER'? (This cannot be undone!)"; then
    # Drop database
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;"
        success "Database $DB_NAME removed"
    else
        warning "Database $DB_NAME not found"
    fi
    
    # Drop user
    if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
        sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;"
        success "Database user $DB_USER removed"
    else
        warning "Database user $DB_USER not found"
    fi
else
    warning "Database and user removal skipped"
fi

# 5. Remove application files
log "Removing application files..."
if [ -d "$PROJECT_DIR" ]; then
    if confirm "Remove all application files in $PROJECT_DIR? (This cannot be undone!)"; then
        # First, change ownership back to current user if needed
        if [ "$(stat -c %U "$PROJECT_DIR")" = "www-data" ]; then
            sudo chown -R "$(whoami):$(whoami)" "$PROJECT_DIR"
        fi
        
        # Remove the directory
        sudo rm -rf "$PROJECT_DIR"
        success "Application files removed from $PROJECT_DIR"
    else
        warning "Application files removal skipped"
    fi
else
    warning "Application directory $PROJECT_DIR not found"
fi

# 6. Remove www-data user modifications (if they were made specifically for this app)
log "Checking www-data user configuration..."
if id "www-data" &>/dev/null; then
    log "www-data user exists (this is normal for web servers)"
else
    warning "www-data user not found"
fi

# 7. Clean up any remaining processes
log "Checking for remaining processes..."
REMAINING_PROCESSES=$(pgrep -f "solvit-ticketing\|it_ticketing_system" || true)
if [ -n "$REMAINING_PROCESSES" ]; then
    warning "Found remaining processes related to SolvIT Ticketing:"
    ps -f -p "$REMAINING_PROCESSES" || true
    if confirm "Kill these processes?"; then
        sudo kill -TERM $REMAINING_PROCESSES 2>/dev/null || true
        sleep 2
        sudo kill -KILL $REMAINING_PROCESSES 2>/dev/null || true
        success "Remaining processes terminated"
    fi
else
    log "No remaining processes found"
fi

# 8. Optional: Remove PostgreSQL if it was installed only for this app
log "PostgreSQL cleanup options..."
if command -v psql >/dev/null 2>&1; then
    if confirm "Remove PostgreSQL completely? (Only if it was installed specifically for this app!)"; then
        warning "This will remove ALL PostgreSQL databases and configurations!"
        if confirm "Are you absolutely sure? This affects ALL PostgreSQL databases on this system!"; then
            sudo systemctl stop postgresql
            sudo systemctl disable postgresql
            sudo apt-get purge -y postgresql postgresql-contrib postgresql-client-common postgresql-common
            sudo rm -rf /var/lib/postgresql/
            sudo rm -rf /etc/postgresql/
            sudo userdel -r postgres 2>/dev/null || true
            success "PostgreSQL completely removed"
        else
            log "PostgreSQL removal cancelled"
        fi
    else
        log "PostgreSQL kept (recommended if used by other applications)"
    fi
else
    log "PostgreSQL not found on system"
fi

# 9. Optional: Remove Python packages that were installed
log "Python packages cleanup..."
if confirm "Remove Python virtual environment packages that might have been installed globally?"; then
    warning "This will attempt to remove packages like django, gunicorn, psycopg2-binary, etc."
    warning "Only proceed if these were installed specifically for this project!"
    if confirm "Continue with Python packages removal?"; then
        # Try to remove common packages (this might fail if they're used by other projects)
        sudo pip3 uninstall -y django gunicorn psycopg2-binary python-dotenv django-jazzmin 2>/dev/null || true
        success "Attempted to remove Python packages"
    fi
else
    log "Python packages cleanup skipped"
fi

# 10. Final cleanup and verification
log "Performing final cleanup..."

# Remove any temporary files
sudo rm -rf /tmp/solvit-ticketing* 2>/dev/null || true

# Clean package cache
sudo apt-get autoremove -y
sudo apt-get autoclean

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    UNINSTALLATION COMPLETE                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

success "SolvIT Ticketing System has been successfully uninstalled!"
echo ""
echo "Summary of actions taken:"
echo "✅ Systemd service stopped and removed"
echo "✅ Application files removed (if confirmed)"
echo "✅ Database and user removed (if confirmed)"
echo "✅ Nginx configuration removed (if found and confirmed)"
echo "✅ System cleanup completed"
echo ""
echo -e "${BLUE}Note: Some system packages (like Python, Nginx, PostgreSQL) may still be${NC}"
echo -e "${BLUE}installed if they were already present or are used by other applications.${NC}"
echo ""
echo -e "${CYAN}Thank you for using SolvIT Ticketing System!${NC}"

# Optional: Show what's still installed that might be related
echo ""
if confirm "Show remaining related packages/services that might still be installed?"; then
    echo ""
    echo -e "${BLUE}Remaining related services:${NC}"
    systemctl list-units --type=service | grep -E "(nginx|postgresql|gunicorn)" || echo "None found"
    
    echo ""
    echo -e "${BLUE}Remaining related packages:${NC}"
    dpkg -l | grep -E "(nginx|postgresql|python3)" || echo "None found"
fi

echo ""
log "Uninstallation script completed successfully!"
