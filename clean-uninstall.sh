#!/bin/bash

# SolvIT Django Ticketing System - Clean Uninstall Script
# This script will completely remove the SolvIT installation

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

echo "🗑️ SolvIT Django Ticketing System - Clean Uninstall"
echo "================================================="
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will completely remove your SolvIT installation!${NC}"
echo -e "${YELLOW}⚠️  All data, including tickets and attachments, will be deleted!${NC}"
echo ""
echo -e "${BLUE}What will be removed:${NC}"
echo "   • Application files in /opt/solvit-ticketing"
echo "   • PostgreSQL database and user"
echo "   • Systemd service"
echo "   • All tickets, attachments, and user data"
echo ""
read -p "Are you sure you want to proceed? (type 'YES' to continue): " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "Uninstall cancelled."
    exit 0
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
fi

log "Starting SolvIT Django Ticketing System uninstall..."

# Stop and disable the service
log "Stopping SolvIT service..."
systemctl stop solvit-ticketing 2>/dev/null || true
systemctl disable solvit-ticketing 2>/dev/null || true

# Remove systemd service file
log "Removing systemd service..."
rm -f /etc/systemd/system/solvit-ticketing.service
systemctl daemon-reload

# Remove application directory
log "Removing application files..."
rm -rf /opt/solvit-ticketing

# Remove system user
log "Removing system user..."
userdel solvit 2>/dev/null || true

# Remove database and user (prompt for database details)
echo ""
echo -e "${BLUE}Database Removal${NC}"
echo "Please provide the database details to remove them:"
read -p "Enter database name [default: solvit_ticketing]: " DB_NAME
DB_NAME=${DB_NAME:-solvit_ticketing}

read -p "Enter database username [default: solvit_user]: " DB_USER
DB_USER=${DB_USER:-solvit_user}

log "Removing PostgreSQL database and user..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;" 2>/dev/null || true

# Remove log files
log "Removing log files..."
rm -f /var/log/solvit-ticketing.log

# Remove firewall rules
log "Removing firewall rules..."
ufw delete allow 8001/tcp 2>/dev/null || true

echo ""
echo "🎉 SolvIT Django Ticketing System Uninstall Complete!"
echo "====================================================="
echo ""
log "✅ Application files removed"
log "✅ Database and user removed"
log "✅ System service removed"
log "✅ System user removed"
log "✅ Log files removed"
log "✅ Firewall rules removed"
echo ""
echo -e "${GREEN}The system is now clean and ready for a fresh installation.${NC}"
echo ""
