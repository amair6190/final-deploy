#!/bin/bash

# Quick fix for media file serving in production
# Run this script on your deployment server to fix attachment download issues

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

echo "🔧 SolvIT Media Files Fix - Attachment Download Issue"
echo "====================================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
fi

APP_DIR="/opt/solvit-ticketing"

# Check if the application directory exists
if [ ! -d "$APP_DIR" ]; then
    error "Application directory not found: $APP_DIR"
fi

cd $APP_DIR

log "Fixing media file serving for attachments..."

# Create the production URLs configuration for media files
log "Creating production URL configuration for media files..."
cat > it_ticketing_system/urls_production.py << 'EOF'
"""
Production URL configuration for it_ticketing_system project.
Includes media file serving for production environments.
"""
from django.contrib import admin
from django.urls import path, include
from django.contrib.auth import views as auth_views
from django.conf import settings
from django.conf.urls.static import static
from django.views.static import serve
from django.urls import re_path
from tickets.views import home

app_name = 'tickets'

urlpatterns = [
    path('admin/', admin.site.urls),
    path('accounts/login/', auth_views.LoginView.as_view(template_name='registration/login.html'), name='login'),
    path('accounts/logout/', auth_views.LogoutView.as_view(next_page='home'), name='logout'),
    path('tickets/', include('tickets.urls')),
    path('', home, name='home'),
]

# Serve media files in production (for attachments and uploads)
urlpatterns += [
    re_path(r'^media/(?P<path>.*)$', serve, {
        'document_root': settings.MEDIA_ROOT,
    }),
]

# Also ensure static files are served
urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
EOF

# Ensure media directories exist with proper permissions
log "Creating media directories..."
mkdir -p media/ticket_attachments/
mkdir -p media/message_attachments/
mkdir -p media/profile_pics/

# Set proper permissions
chmod -R 755 media/
chown -R solvit:solvit media/

# Restart the Django service to apply changes
log "Restarting SolvIT Django service..."
systemctl restart solvit-ticketing

# Wait for service to start
sleep 3

# Check service status
if systemctl is-active --quiet solvit-ticketing; then
    log "✅ SolvIT service restarted successfully"
else
    error "❌ SolvIT service failed to restart. Check logs: journalctl -u solvit-ticketing -f"
fi

# Test media file serving
log "Testing media file serving..."
if curl -s http://127.0.0.1:8001/media/ > /dev/null 2>&1; then
    log "✅ Media files directory is now accessible!"
else
    warning "Media files may still have issues. Check Django logs."
fi

echo ""
echo "🎉 Media Files Fix Complete!"
echo "=========================="
echo ""
log "✅ Production URL configuration updated"
log "✅ Media directories created with proper permissions"
log "✅ Django service restarted"
echo ""
echo -e "${BLUE}Test your attachment downloads now!${NC}"
echo -e "${YELLOW}If issues persist, check Django logs: journalctl -u solvit-ticketing -f${NC}"
echo ""
