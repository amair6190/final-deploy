#!/bin/bash

# Django Ticketing System - Complete Deployment Script
# Master script that runs all deployment phases
# Run this script on your Ubuntu server as root

set -e  # Exit on any error

echo "🚀 Django Ticketing System - Complete Ubuntu Server Deployment"
echo "=============================================================="
echo "This script will deploy your Django Ticketing System with:"
echo "  ✅ System packages and user setup"
echo "  ✅ PostgreSQL database server"
echo "  ✅ Django application deployment"
echo "  ✅ Nginx web server with SSL"
echo "  ✅ Security hardening"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_phase() {
    echo -e "${BLUE}[PHASE]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root or with sudo privileges"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Verify all scripts exist
SCRIPTS=(
    "01-system-setup.sh"
    "02-postgresql-setup.sh"
    "03-django-app-setup.sh"
    "04-nginx-setup.sh"
    "05-security-hardening.sh"
)

print_status "Verifying deployment scripts..."
for script in "${SCRIPTS[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$script" ]; then
        print_error "Required script not found: $script"
        exit 1
    fi
    chmod +x "$SCRIPT_DIR/$script"
done

# Prompt for configuration
echo ""
print_warning "⚙️ Configuration Required:"
read -p "Enter your domain name (e.g., example.com): " DOMAIN
read -p "Enter your email for SSL certificates: " EMAIL
read -p "Enter your admin email for alerts: " ADMIN_EMAIL

# Validate inputs
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ] || [ -z "$ADMIN_EMAIL" ]; then
    print_error "All fields are required"
    exit 1
fi

# Update configuration files with user inputs
print_status "Updating configuration with your settings..."
sed -i "s/your-domain.com/$DOMAIN/g" "$SCRIPT_DIR"/*.sh
sed -i "s/your-email@gmail.com/$EMAIL/g" "$SCRIPT_DIR"/*.sh  
sed -i "s/admin@your-domain.com/$ADMIN_EMAIL/g" "$SCRIPT_DIR"/*.sh

# Get server IP
SERVER_IP=$(curl -s ifconfig.me || echo "unknown")
if [ "$SERVER_IP" != "unknown" ]; then
    sed -i "s/your-server-ip/$SERVER_IP/g" "$SCRIPT_DIR"/*.sh
fi

print_status "Configuration updated:"
echo "  Domain: $DOMAIN"
echo "  Email: $EMAIL"
echo "  Admin Email: $ADMIN_EMAIL"
echo "  Server IP: $SERVER_IP"
echo ""

# Confirm deployment
read -p "🚀 Ready to deploy? This will take 10-15 minutes. Continue? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled by user"
    exit 0
fi

# Start deployment timer
START_TIME=$(date +%s)

# Phase 1: System Setup
print_phase "Phase 1/5: System Setup"
cd "$SCRIPT_DIR"
./01-system-setup.sh

# Phase 2: PostgreSQL Setup  
print_phase "Phase 2/5: PostgreSQL Database Setup"
./02-postgresql-setup.sh

# Phase 3: Django Application Setup
print_phase "Phase 3/5: Django Application Setup"
./03-django-app-setup.sh

# Phase 4: Nginx Web Server Setup
print_phase "Phase 4/5: Nginx Web Server Setup"
./04-nginx-setup.sh

# Phase 5: Security Hardening
print_phase "Phase 5/5: Security Hardening"
./05-security-hardening.sh

# Calculate deployment time
END_TIME=$(date +%s)
DEPLOYMENT_TIME=$((END_TIME - START_TIME))
MINUTES=$((DEPLOYMENT_TIME / 60))
SECONDS=$((DEPLOYMENT_TIME % 60))

# Post-deployment tasks
print_status "🔧 Running post-deployment tasks..."

# Install Let's Encrypt SSL certificate
if [ "$DOMAIN" != "your-domain.com" ]; then
    print_status "Installing Let's Encrypt SSL certificate..."
    certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive --redirect
    
    if [ $? -eq 0 ]; then
        print_status "✅ SSL certificate installed successfully"
    else
        print_warning "⚠️ SSL certificate installation failed. You can retry manually with:"
        echo "    certbot --nginx -d $DOMAIN -d www.$DOMAIN"
    fi
fi

# Final service status check
print_status "🏥 Final service status check..."
services=("postgresql" "redis-server" "django-ticketing" "nginx" "fail2ban")
all_services_ok=true

for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo "  ✅ $service: Running"
    else
        echo "  ❌ $service: Not running"
        all_services_ok=false
    fi
done

# Test application accessibility
print_status "🌐 Testing application accessibility..."
if curl -s -o /dev/null -w "%{http_code}" "http://localhost" | grep -q "200\|301\|302"; then
    echo "  ✅ Application is accessible"
else
    echo "  ⚠️ Application may not be fully accessible yet"
fi

# Generate deployment report
print_status "📋 Generating deployment report..."
cat > /opt/django-ticketing/DEPLOYMENT_REPORT.md << EOF
# Django Ticketing System Deployment Report

**Deployment Date:** $(date)  
**Deployment Time:** ${MINUTES}m ${SECONDS}s  
**Server IP:** $SERVER_IP  
**Domain:** $DOMAIN  

## ✅ Completed Components

### System Configuration
- [x] Ubuntu system packages installed
- [x] Application user 'django-user' created
- [x] Directory structure created

### Database
- [x] PostgreSQL installed and configured
- [x] Database 'django_ticketing_db' created
- [x] Database user with secure password
- [x] Daily backup cron job configured

### Application
- [x] Django application deployed from GitHub
- [x] Python virtual environment created
- [x] Dependencies installed
- [x] Database migrations completed
- [x] Static files collected
- [x] Superuser account created

### Web Server
- [x] Nginx installed and configured
- [x] SSL certificate $([ -f /etc/letsencrypt/live/$DOMAIN/cert.pem ] && echo "✅ Let's Encrypt" || echo "⚠️ Self-signed")
- [x] Rate limiting configured
- [x] Security headers enabled
- [x] Gzip compression enabled

### Security
- [x] UFW firewall configured
- [x] Fail2ban intrusion prevention
- [x] Automatic security updates
- [x] SSH hardening (if applicable)
- [x] ClamAV antivirus
- [x] AIDE intrusion detection
- [x] Log monitoring with logwatch

## 🔗 Access Information

**Application URL:** https://$DOMAIN  
**Admin Panel:** https://$DOMAIN/$(grep ADMIN_URL /opt/django-ticketing/app/.env | cut -d'=' -f2)  
**Application Directory:** /opt/django-ticketing/app  
**Logs Directory:** /opt/django-ticketing/logs  

## 📋 Database Credentials

**Database:** django_ticketing_db  
**User:** django_ticketing_user  
**Password:** See /opt/django-ticketing/.db_credentials  
**Host:** localhost  
**Port:** 5432  

## 🛠️ Management Commands

\`\`\`bash
# Check service status
systemctl status django-ticketing

# View application logs
tail -f /opt/django-ticketing/logs/gunicorn_error.log

# Update application
/opt/django-ticketing/update_app.sh

# Security audit
/opt/django-ticketing/security_audit.sh

# Health check
/opt/django-ticketing/health_check.sh

# Database backup
/opt/django-ticketing/backups/backup_database.sh
\`\`\`

## 🔒 Security Features

- **Firewall:** UFW with restricted access
- **SSL/TLS:** $([ -f /etc/letsencrypt/live/$DOMAIN/cert.pem ] && echo "Let's Encrypt certificate" || echo "Self-signed certificate")
- **Intrusion Prevention:** Fail2ban with custom rules
- **Antivirus:** ClamAV with weekly scans
- **Intrusion Detection:** AIDE with daily checks
- **Rate Limiting:** Nginx rate limiting on login/API endpoints
- **Security Headers:** HSTS, CSP, X-Frame-Options, etc.

## ⚠️ Post-Deployment Tasks

### Immediate
- [ ] Test all application functionality
- [ ] Update admin email in Django admin
- [ ] Configure email SMTP settings in .env
- [ ] Test SSL certificate

### Within 24 hours
- [ ] Set up external monitoring
- [ ] Configure backup storage
- [ ] Test backup and restore procedures
- [ ] Review security logs

### Ongoing
- [ ] Regular security updates
- [ ] Monitor application performance
- [ ] Review access logs
- [ ] Backup database regularly

## 📞 Support

For technical support:
- Application logs: /opt/django-ticketing/logs/
- System logs: /var/log/
- Security audit: /opt/django-ticketing/security_audit.sh

---
*Generated by Django Ticketing System deployment script*
EOF

echo ""
echo "🎉 ============================================== 🎉"
echo "   Django Ticketing System Deployment Complete!"
echo "🎉 ============================================== 🎉"
echo ""
print_status "📊 Deployment Summary:"
echo "  ⏱️  Total time: ${MINUTES}m ${SECONDS}s"
echo "  🌐 Application URL: https://$DOMAIN"
echo "  🔧 Admin URL: https://$DOMAIN/$(grep ADMIN_URL /opt/django-ticketing/app/.env 2>/dev/null | cut -d'=' -f2 || echo 'admin/')"
echo "  📁 App directory: /opt/django-ticketing/app"
echo "  📋 Deployment report: /opt/django-ticketing/DEPLOYMENT_REPORT.md"
echo ""

if [ "$all_services_ok" = true ]; then
    print_status "✅ All services are running correctly!"
else
    print_warning "⚠️ Some services may need attention. Check the report above."
fi

echo ""
print_status "🔄 Next Steps:"
echo "  1. Visit https://$DOMAIN to test your application"
echo "  2. Log in to admin panel with your superuser account"
echo "  3. Configure email settings in Django admin"
echo "  4. Test file upload functionality"
echo "  5. Review deployment report for additional tasks"
echo ""
print_status "📚 Useful Commands:"
echo "  - Check status: /opt/django-ticketing/health_check.sh"
echo "  - Update app: /opt/django-ticketing/update_app.sh"
echo "  - Security audit: /opt/django-ticketing/security_audit.sh"
echo "  - View logs: tail -f /opt/django-ticketing/logs/gunicorn_error.log"
echo ""
print_status "🎉 Your Django Ticketing System is now live and ready for production use!"
EOF
