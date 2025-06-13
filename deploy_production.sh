#!/bin/bash

# Production Deployment Script for Django Ticketing System
# This script automates the deployment process with security checks

set -e  # Exit on any error

echo "🚀 Starting Production Deployment for Django Ticketing System"
echo "=============================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_error ".env file not found!"
    print_status "Copy .env.example to .env and configure your settings"
    exit 1
fi

print_success ".env file found"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    print_status "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
print_status "Activating virtual environment..."
source venv/bin/activate

# Install/update dependencies
print_status "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Check environment variables
print_status "Checking environment configuration..."
python -c "
import os
from pathlib import Path
import sys

# Load environment variables
from dotenv import load_dotenv
load_dotenv()

errors = []
warnings = []

# Check critical environment variables
required_vars = ['SECRET_KEY', 'DB_NAME', 'DB_USER', 'DB_PASSWORD']
for var in required_vars:
    if not os.getenv(var):
        errors.append(f'Missing required environment variable: {var}')

# Check SECRET_KEY
secret_key = os.getenv('SECRET_KEY', '')
if 'django-insecure' in secret_key:
    errors.append('SECRET_KEY is still using default insecure value')
elif len(secret_key) < 50:
    warnings.append('SECRET_KEY should be at least 50 characters long')

# Check DEBUG setting
debug = os.getenv('DEBUG', 'True').lower()
if debug == 'true':
    errors.append('DEBUG is set to True - must be False for production')

# Check ALLOWED_HOSTS
allowed_hosts = os.getenv('ALLOWED_HOSTS', '')
if not allowed_hosts or allowed_hosts == 'your-domain.com':
    errors.append('ALLOWED_HOSTS not properly configured')

if errors:
    print('❌ CRITICAL ERRORS:')
    for error in errors:
        print(f'  - {error}')
    sys.exit(1)

if warnings:
    print('⚠️  WARNINGS:')
    for warning in warnings:
        print(f'  - {warning}')

print('✅ Environment configuration validated')
"

if [ $? -ne 0 ]; then
    print_error "Environment validation failed!"
    exit 1
fi

# Run security checks
print_status "Running security validation..."
python check_security.py

if [ $? -ne 0 ]; then
    print_error "Security validation failed!"
    print_warning "Please fix security issues before proceeding"
    exit 1
fi

# Database migrations
print_status "Running database migrations..."
python manage.py makemigrations --settings=it_ticketing_system.settings_production
python manage.py migrate --settings=it_ticketing_system.settings_production

# Collect static files
print_status "Collecting static files..."
python manage.py collectstatic --noinput --settings=it_ticketing_system.settings_production

# Create superuser if it doesn't exist
print_status "Checking for superuser..."
python manage.py shell --settings=it_ticketing_system.settings_production << EOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(is_superuser=True).exists():
    print("No superuser found. Please create one manually after deployment.")
    print("Run: python manage.py createsuperuser --settings=it_ticketing_system.settings_production")
else:
    print("Superuser already exists")
EOF

# Run Django deployment check
print_status "Running Django deployment check..."
python manage.py check --deploy --settings=it_ticketing_system.settings_production

if [ $? -ne 0 ]; then
    print_error "Django deployment check failed!"
    exit 1
fi

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p logs
mkdir -p media/ticket_attachments
mkdir -p media/message_attachments

# Set proper permissions
print_status "Setting file permissions..."
chmod 600 .env
chmod 755 media
chmod 755 logs
chmod -R 644 staticfiles
find staticfiles -type d -exec chmod 755 {} \;

# Test server startup
print_status "Testing server startup..."
timeout 10s python manage.py runserver 127.0.0.1:8001 --settings=it_ticketing_system.settings_production &
SERVER_PID=$!
sleep 5

if kill -0 $SERVER_PID 2>/dev/null; then
    print_success "Server started successfully"
    kill $SERVER_PID
else
    print_error "Server failed to start"
    exit 1
fi

print_success "Production deployment preparation completed successfully!"

echo ""
echo "=============================================================="
echo "🎉 DEPLOYMENT READY!"
echo "=============================================================="
echo ""
echo "Next steps for production deployment:"
echo ""
echo "1. 🔧 Web Server Configuration:"
echo "   - Configure Nginx/Apache with SSL"
echo "   - Set up reverse proxy to Django"
echo "   - Configure static file serving"
echo ""
echo "2. 🔐 Security Setup:"
echo "   - Install SSL certificate (Let's Encrypt recommended)"
echo "   - Configure firewall (UFW/iptables)"
echo "   - Set up fail2ban for intrusion prevention"
echo ""
echo "3. 📊 Monitoring Setup:"
echo "   - Configure log rotation"
echo "   - Set up monitoring (htop, netdata, etc.)"
echo "   - Configure database backups"
echo ""
echo "4. 🚀 Start Production Server:"
echo "   gunicorn --bind 127.0.0.1:8000 --workers 3 --settings=it_ticketing_system.settings_production it_ticketing_system.wsgi:application"
echo ""
echo "5. 🔍 Post-deployment Testing:"
echo "   - Test all functionality"
echo "   - Verify SSL configuration"
echo "   - Check security headers"
echo ""

# Display important information
echo "📋 IMPORTANT INFORMATION:"
echo ""
echo "Admin Panel URL: https://yourdomain.com/${ADMIN_URL:-secure-admin-panel/}"
echo "Application URL: https://yourdomain.com/"
echo "Static Files: Served by WhiteNoise"
echo "Media Files: /media/ directory"
echo ""

print_warning "Remember to:"
print_warning "- Update DNS records to point to your server"
print_warning "- Configure email settings for notifications"  
print_warning "- Set up regular database backups"
print_warning "- Monitor logs regularly"

echo ""
print_success "Deployment script completed successfully! 🎉"
