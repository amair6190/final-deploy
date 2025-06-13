#!/bin/bash

# Django Ticketing System - One-Line Deployment
# This script downloads and runs the complete deployment

set -e

echo "🚀 Django Ticketing System - HTTP-Only Deployment"
echo "=================================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Get the deployment scripts
TEMP_DIR="/tmp/django-ticketing-deploy-$(date +%s)"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo "📥 Downloading deployment scripts..."

# If scripts are available locally, copy them
if [ -d "/opt/django-ticketing-scripts" ]; then
    cp -r /opt/django-ticketing-scripts/* .
else
    # Download from GitHub or use curl/wget
    echo "⚠️  Please ensure deployment scripts are available in current directory"
    echo "   Expected files:"
    echo "   - 01-system-setup.sh"
    echo "   - 02-postgresql-setup.sh" 
    echo "   - 03-django-app-setup.sh"
    echo "   - 04-nginx-setup-no-ssl.sh"
    echo "   - 05-security-hardening.sh"
    echo "   - deploy-http-only.sh"
    echo ""
    echo "💡 Run this script from the directory containing these files"
    exit 1
fi

# Make scripts executable
chmod +x *.sh

echo "✅ Scripts downloaded successfully"
echo ""

# Run the main deployment script
echo "🚀 Starting deployment..."
./deploy-http-only.sh

echo ""
echo "🎉 Deployment completed!"
echo "💡 Check the deployment report for details"
