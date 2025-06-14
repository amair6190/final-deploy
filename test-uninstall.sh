#!/bin/bash

# SolvIT Django Ticketing System - Uninstall Script Test
# This script tests the uninstall functionality without performing destructive operations

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
    echo -e "${GREEN}[TEST]${NC} $1"
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

# Banner
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    SolvIT Ticketing System                   ║"
echo "║                   UNINSTALL SCRIPT TEST                      ║"
echo "║                                                              ║"
echo "║        🧪  Testing Uninstall Components 🧪                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

log "Testing uninstall script components..."

# Test variables
PROJECT_DIR="/opt/solvit-ticketing"
SERVICE_NAME="solvit-ticketing"
DB_NAME="test2"
DB_USER="test2"
NGINX_SITE="solvit-ticketing"

echo "Configuration to test:"
echo "  Project Directory: $PROJECT_DIR"
echo "  Service Name: $SERVICE_NAME"
echo "  Database Name: $DB_NAME"
echo "  Database User: $DB_USER"
echo "  Nginx Site: $NGINX_SITE"
echo ""

# 1. Check if systemd service exists
log "Checking systemd service..."
if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        success "Service $SERVICE_NAME is running"
    else
        warning "Service $SERVICE_NAME exists but is not running"
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        log "Service $SERVICE_NAME is enabled (auto-start)"
    else
        log "Service $SERVICE_NAME is not enabled"
    fi
else
    warning "Service $SERVICE_NAME not found"
fi

# Check service file
if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
    success "Service file exists at /etc/systemd/system/$SERVICE_NAME.service"
else
    warning "Service file not found"
fi

# 2. Check application directory
log "Checking application directory..."
if [ -d "$PROJECT_DIR" ]; then
    success "Application directory exists: $PROJECT_DIR"
    
    # Check key files
    if [ -f "$PROJECT_DIR/manage.py" ]; then
        success "Django manage.py found"
    else
        warning "Django manage.py not found"
    fi
    
    if [ -d "$PROJECT_DIR/venv" ]; then
        success "Virtual environment found"
    else
        warning "Virtual environment not found"
    fi
    
    if [ -d "$PROJECT_DIR/staticfiles" ]; then
        success "Static files directory found"
        STATIC_COUNT=$(find "$PROJECT_DIR/staticfiles" -type f | wc -l)
        log "Static files count: $STATIC_COUNT"
    else
        warning "Static files directory not found"
    fi
    
    if [ -d "$PROJECT_DIR/media" ]; then
        success "Media directory found"
        MEDIA_COUNT=$(find "$PROJECT_DIR/media" -type f | wc -l)
        log "Media files count: $MEDIA_COUNT"
    else
        log "Media directory not found (normal if no uploads)"
    fi
    
    # Check directory ownership
    OWNER=$(stat -c %U "$PROJECT_DIR")
    log "Directory owner: $OWNER"
    
else
    error "Application directory not found: $PROJECT_DIR"
fi

# 3. Check database
log "Checking PostgreSQL database..."
if command -v psql >/dev/null 2>&1; then
    success "PostgreSQL client found"
    
    if systemctl is-active --quiet postgresql; then
        success "PostgreSQL service is running"
    else
        warning "PostgreSQL service is not running"
    fi
    
    # Check if database exists
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        success "Database $DB_NAME exists"
        
        # Get database size
        DB_SIZE=$(sudo -u postgres psql -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" -t | xargs)
        log "Database size: $DB_SIZE"
        
        # Count tables
        TABLE_COUNT=$(sudo -u postgres psql -d "$DB_NAME" -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" -t | xargs)
        log "Number of tables: $TABLE_COUNT"
    else
        warning "Database $DB_NAME not found"
    fi
    
    # Check if user exists
    if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
        success "Database user $DB_USER exists"
    else
        warning "Database user $DB_USER not found"
    fi
else
    error "PostgreSQL not installed or not in PATH"
fi

# 4. Check Nginx configuration
log "Checking Nginx configuration..."
if command -v nginx >/dev/null 2>&1; then
    success "Nginx found"
    
    if systemctl is-active --quiet nginx; then
        success "Nginx service is running"
    else
        warning "Nginx service is not running"
    fi
    
    if [ -f "/etc/nginx/sites-available/$NGINX_SITE" ]; then
        success "Nginx site configuration found"
        
        if [ -L "/etc/nginx/sites-enabled/$NGINX_SITE" ]; then
            success "Nginx site is enabled"
        else
            warning "Nginx site is not enabled"
        fi
    else
        log "Nginx site configuration not found (may not be configured)"
    fi
else
    log "Nginx not installed"
fi

# 5. Check for running processes
log "Checking for related processes..."
GUNICORN_PROCESSES=$(pgrep -f "gunicorn.*it_ticketing_system" | wc -l)
if [ "$GUNICORN_PROCESSES" -gt 0 ]; then
    success "Found $GUNICORN_PROCESSES Gunicorn processes"
    pgrep -f "gunicorn.*it_ticketing_system" | head -3 | while read pid; do
        log "Process PID: $pid"
    done
else
    log "No Gunicorn processes found"
fi

# Check for any solvit-related processes
SOLVIT_PROCESSES=$(pgrep -f "solvit" | wc -l)
if [ "$SOLVIT_PROCESSES" -gt 0 ]; then
    log "Found $SOLVIT_PROCESSES SolvIT-related processes"
else
    log "No SolvIT-related processes found"
fi

# 6. Check Python packages
log "Checking Python packages..."
if [ -f "$PROJECT_DIR/venv/bin/pip" ]; then
    log "Checking packages in virtual environment..."
    DJANGO_VERSION=$("$PROJECT_DIR/venv/bin/pip" show django 2>/dev/null | grep Version | cut -d' ' -f2)
    if [ -n "$DJANGO_VERSION" ]; then
        success "Django $DJANGO_VERSION installed in venv"
    fi
    
    JAZZMIN_VERSION=$("$PROJECT_DIR/venv/bin/pip" show django-jazzmin 2>/dev/null | grep Version | cut -d' ' -f2)
    if [ -n "$JAZZMIN_VERSION" ]; then
        success "django-jazzmin $JAZZMIN_VERSION installed in venv"
    fi
    
    GUNICORN_VERSION=$("$PROJECT_DIR/venv/bin/pip" show gunicorn 2>/dev/null | grep Version | cut -d' ' -f2)
    if [ -n "$GUNICORN_VERSION" ]; then
        success "gunicorn $GUNICORN_VERSION installed in venv"
    fi
fi

# 7. Disk usage check
log "Checking disk usage..."
if [ -d "$PROJECT_DIR" ]; then
    PROJECT_SIZE=$(du -sh "$PROJECT_DIR" 2>/dev/null | cut -f1)
    log "Total project size: $PROJECT_SIZE"
fi

# Summary
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                        TEST SUMMARY                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

log "Test completed successfully!"
echo ""
echo "Components found for potential removal:"
echo "✓ Systemd service: $(systemctl list-unit-files | grep -q "$SERVICE_NAME.service" && echo "YES" || echo "NO")"
echo "✓ Application files: $([ -d "$PROJECT_DIR" ] && echo "YES" || echo "NO")"
echo "✓ Database: $(sudo -u postgres psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$DB_NAME" && echo "YES" || echo "NO")"
echo "✓ Database user: $(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" 2>/dev/null | grep -q 1 && echo "YES" || echo "NO")"
echo "✓ Nginx config: $([ -f "/etc/nginx/sites-available/$NGINX_SITE" ] && echo "YES" || echo "NO")"

echo ""
echo -e "${YELLOW}Note: This is a test script. No actual removal was performed.${NC}"
echo -e "${CYAN}Run './uninstall-solvit-ticketing.sh' to perform actual uninstallation.${NC}"
