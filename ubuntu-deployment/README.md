# 🚀 Django Ticketing System - Ubuntu Server Deployment

Complete production deployment scripts for deploying Django Ticketing System on Ubuntu Server with PostgreSQL database.

## 📋 Overview

This deployment package includes everything needed to deploy a production-ready Django Ticketing System on Ubuntu Server 20.04/22.04 with:

- ✅ **PostgreSQL Database Server**
- ✅ **Nginx Web Server with SSL**
- ✅ **Gunicorn WSGI Server**
- ✅ **Redis Caching**
- ✅ **Security Hardening**
- ✅ **Monitoring & Backup Systems**
- ✅ **Automated Deployment**

## 📁 Deployment Scripts

| Script | Description | Phase |
|--------|-------------|-------|
| `deploy.sh` | 🎯 **Master deployment script** - Runs all phases | All |
| `01-system-setup.sh` | System packages and user creation | 1 |
| `02-postgresql-setup.sh` | PostgreSQL database configuration | 2 |
| `03-django-app-setup.sh` | Django application deployment | 3 |
| `04-nginx-setup.sh` | Nginx web server and SSL setup | 4 |
| `05-security-hardening.sh` | Security configuration and hardening | 5 |

## 🚀 Quick Deployment

### Prerequisites
- Ubuntu Server 20.04/22.04 LTS
- Root or sudo access
- Domain name pointed to your server (optional but recommended)
- SSH access to the server

### One-Command Deployment
```bash
# Upload deployment scripts to your server
scp -r ubuntu-deployment/ user@your-server:/tmp/

# SSH to your server and run deployment
ssh user@your-server
cd /tmp/ubuntu-deployment
sudo chmod +x *.sh
sudo ./deploy.sh
```

### Manual Phase-by-Phase Deployment
```bash
# Phase 1: System Setup
sudo ./01-system-setup.sh

# Phase 2: Database Setup
sudo ./02-postgresql-setup.sh

# Phase 3: Django Application
sudo ./03-django-app-setup.sh

# Phase 4: Web Server
sudo ./04-nginx-setup.sh

# Phase 5: Security Hardening
sudo ./05-security-hardening.sh
```

## ⚙️ Configuration

The deployment script will prompt you for:

1. **Domain Name** (e.g., `example.com`)
2. **Email Address** (for SSL certificates)
3. **Admin Email** (for alerts and notifications)

These values will be automatically configured across all components.

## 📊 What Gets Installed

### System Components
```
├── Python 3.x + Virtual Environment
├── PostgreSQL 14+ Database Server
├── Nginx Web Server
├── Redis Cache Server
├── Supervisor Process Manager
├── Git Version Control
└── Essential System Tools
```

### Security Components
```
├── UFW Firewall (configured)
├── Fail2ban Intrusion Prevention
├── ClamAV Antivirus
├── AIDE Intrusion Detection
├── SSL/TLS Certificates (Let's Encrypt)
├── Security Headers & CSP
└── Automated Security Updates
```

### Monitoring & Maintenance
```
├── Logwatch Log Analysis
├── Automated Database Backups
├── Health Check Scripts
├── Security Audit Scripts
├── Service Monitoring
└── SSL Certificate Auto-renewal
```

## 🏗️ Directory Structure After Deployment

```
/opt/django-ticketing/
├── app/                          # Django application
│   ├── venv/                     # Python virtual environment
│   ├── media/                    # User uploaded files
│   ├── static/                   # Static assets
│   ├── logs/                     # Application logs
│   ├── .env                      # Environment configuration
│   └── manage.py                 # Django management
├── backups/                      # Database backups
│   └── backup_database.sh        # Backup script
├── logs/                         # System logs
├── ssl/                          # SSL certificates (if any)
├── .db_credentials              # Database credentials
├── update_app.sh                # Application update script
├── health_check.sh              # Health monitoring script
├── security_audit.sh            # Security audit script
├── virus_scan.sh                # Antivirus scan script
└── DEPLOYMENT_REPORT.md         # Deployment summary
```

## 🔐 Security Features

### Network Security
- **UFW Firewall**: Only required ports open (22, 80, 443)
- **Fail2ban**: Automatic IP banning for failed attempts
- **Rate Limiting**: Nginx-level rate limiting on sensitive endpoints
- **SSH Hardening**: Key-only authentication, root login disabled

### Application Security
- **SSL/TLS**: Let's Encrypt certificates with auto-renewal
- **Security Headers**: HSTS, CSP, X-Frame-Options, etc.
- **Secure Cookies**: HTTPOnly and Secure flags
- **CSRF Protection**: Django CSRF middleware
- **SQL Injection Protection**: Django ORM protection

### File System Security
- **File Permissions**: Restrictive permissions on sensitive files
- **User Separation**: Dedicated system user for application
- **Antivirus Scanning**: Weekly ClamAV scans
- **Integrity Monitoring**: AIDE file system monitoring

## 📋 Post-Deployment Checklist

### Immediate (0-1 hour)
- [ ] Test application accessibility: `https://your-domain.com`
- [ ] Login to admin panel and verify functionality
- [ ] Test file upload feature
- [ ] Verify SSL certificate installation
- [ ] Check all services status: `/opt/django-ticketing/health_check.sh`

### Within 24 hours
- [ ] Configure email settings in Django admin
- [ ] Set up external monitoring (optional)
- [ ] Test backup and restore procedures
- [ ] Review security audit: `/opt/django-ticketing/security_audit.sh`
- [ ] Configure DNS records properly

### Ongoing Maintenance
- [ ] Monitor application logs: `/opt/django-ticketing/logs/`
- [ ] Regular security updates: `apt update && apt upgrade`
- [ ] Review backup integrity weekly
- [ ] Monitor disk space usage
- [ ] Review access logs for suspicious activity

## 🛠️ Management Commands

### Service Management
```bash
# Check all services status
systemctl status django-ticketing nginx postgresql redis-server

# Restart Django application
systemctl restart django-ticketing

# Reload Nginx configuration
systemctl reload nginx

# View real-time logs
tail -f /opt/django-ticketing/logs/gunicorn_error.log
```

### Application Management
```bash
# Update application from Git
/opt/django-ticketing/update_app.sh

# Django management commands
cd /opt/django-ticketing/app
sudo -u django-user ./venv/bin/python manage.py <command>

# Create new superuser
sudo -u django-user ./venv/bin/python manage.py createsuperuser

# Collect static files
sudo -u django-user ./venv/bin/python manage.py collectstatic
```

### Database Management
```bash
# Manual database backup
/opt/django-ticketing/backups/backup_database.sh

# Access PostgreSQL
sudo -u postgres psql django_ticketing_db

# View database credentials
sudo cat /opt/django-ticketing/.db_credentials
```

### Security & Monitoring
```bash
# Run security audit
/opt/django-ticketing/security_audit.sh

# Check health status
/opt/django-ticketing/health_check.sh

# Manual virus scan
/opt/django-ticketing/virus_scan.sh

# Check firewall status
ufw status verbose

# View fail2ban status
fail2ban-client status
```

## 🔧 Troubleshooting

### Common Issues

**Application not accessible:**
```bash
# Check service status
systemctl status django-ticketing nginx
# Check logs
tail -f /opt/django-ticketing/logs/gunicorn_error.log
tail -f /var/log/nginx/error.log
```

**SSL certificate issues:**
```bash
# Manually install Let's Encrypt
certbot --nginx -d your-domain.com -d www.your-domain.com
# Check certificate status
certbot certificates
```

**Database connection errors:**
```bash
# Check PostgreSQL status
systemctl status postgresql
# Test database connection
sudo -u postgres psql django_ticketing_db -c "SELECT 1;"
```

**Permission errors:**
```bash
# Fix application permissions
chown -R django-user:django-user /opt/django-ticketing/app
chmod 600 /opt/django-ticketing/app/.env
```

### Log Locations
- **Application Logs**: `/opt/django-ticketing/logs/`
- **Nginx Logs**: `/var/log/nginx/`
- **PostgreSQL Logs**: `/var/log/postgresql/`
- **System Logs**: `/var/log/syslog`
- **Security Logs**: `/var/log/auth.log`

## 📞 Support

### Getting Help
1. Check the deployment report: `/opt/django-ticketing/DEPLOYMENT_REPORT.md`
2. Run health check: `/opt/django-ticketing/health_check.sh`
3. Review application logs in `/opt/django-ticketing/logs/`
4. Check service status with `systemctl status <service>`

### Best Practices
- **Regular Backups**: Automated daily database backups are configured
- **Security Updates**: Automatic security updates are enabled
- **Monitoring**: Use the provided health check and audit scripts
- **SSL Renewal**: Certificates auto-renew via cron job
- **Log Rotation**: Configured to prevent log files from growing too large

## 🎯 Performance Optimization

### Recommended Server Specs
- **Minimum**: 2 CPU cores, 4GB RAM, 20GB storage
- **Recommended**: 4 CPU cores, 8GB RAM, 50GB+ storage
- **Production**: 8+ CPU cores, 16GB+ RAM, SSD storage

### Performance Tuning
```bash
# Adjust Gunicorn workers (CPU cores * 2 + 1)
# Edit: /etc/systemd/system/django-ticketing.service

# PostgreSQL tuning based on server specs
# Edit: /etc/postgresql/*/main/postgresql.conf

# Nginx optimization
# Edit: /etc/nginx/conf.d/django-ticketing-optimization.conf
```

## 🚀 Ready for Production!

Your Django Ticketing System is now deployed with:
- ✅ Production-grade security
- ✅ Automated monitoring and backups
- ✅ SSL encryption
- ✅ Performance optimization
- ✅ Comprehensive logging

**Access your application at**: `https://your-domain.com`  
**Admin panel**: `https://your-domain.com/admin/`

---

*Django Ticketing System Ubuntu Deployment Package*  
*Version: 1.0 | Updated: June 2025*
