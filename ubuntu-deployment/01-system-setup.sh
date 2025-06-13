#!/bin/bash

# Django Ticketing System - Ubuntu Server System Setup Script
# Phase 1: System packages and user creation
# Run this script on your Ubuntu server as root or with sudo privileges

set -e  # Exit on any error

echo "🚀 Django Ticketing System - Ubuntu Server System Setup"
echo "======================================================"
echo "Phase 1: Installing system packages and creating application user"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root or with sudo privileges"
    exit 1
fi

# Update system packages
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install essential packages
print_status "Installing essential packages..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    git \
    nginx \
    postgresql \
    postgresql-contrib \
    postgresql-server-dev-all \
    redis-server \
    supervisor \
    curl \
    wget \
    unzip \
    build-essential \
    libpq-dev \
    libssl-dev \
    libffi-dev \
    ufw \
    htop \
    tree \
    nano \
    vim

# Install Node.js for frontend assets (if needed)
print_status "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Create application user
print_status "Creating application user..."
if id "django-user" &>/dev/null; then
    print_warning "User 'django-user' already exists"
else
    useradd --system --shell /bin/bash --home /opt/django-ticketing --create-home django-user
    print_status "Created user 'django-user'"
fi

# Create application directory structure
print_status "Creating application directory structure..."
mkdir -p /opt/django-ticketing/{app,backups,logs,ssl}
chown -R django-user:django-user /opt/django-ticketing

# Set up log rotation
print_status "Setting up log rotation..."
cat > /etc/logrotate.d/django-ticketing << 'EOF'
/opt/django-ticketing/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 django-user django-user
    postrotate
        supervisorctl restart django_ticketing > /dev/null 2>&1 || true
    endscript
}
EOF

# Install Python packages globally needed for deployment
print_status "Installing Python deployment tools..."
pip3 install --upgrade pip setuptools wheel

print_status "✅ Phase 1 Complete: System packages and application user created"
print_status "📋 Summary:"
echo "   - System packages installed and updated"
echo "   - Application user 'django-user' created"
echo "   - Directory structure created in /opt/django-ticketing"
echo "   - Log rotation configured"
echo ""
print_status "🔄 Next: Run 02-postgresql-setup.sh to configure the database"
