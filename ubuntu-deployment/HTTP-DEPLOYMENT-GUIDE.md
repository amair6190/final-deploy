# Django Ticketing System - HTTP-Only Deployment Guide

## 🚀 **One-Command Deployment**

Upload your project to Ubuntu server and run:
```bash
sudo ./deploy-http-only.sh
```

That's it! The script will handle everything automatically.

---

## 📋 **What the Deployment Script Does**

### **Phase 1: System Setup**
- Updates Ubuntu packages
- Installs Python, PostgreSQL, Nginx, Git
- Configures system dependencies
- Sets up user permissions

### **Phase 2: Database Setup**
- Installs and configures PostgreSQL
- Creates database and user
- Sets up proper permissions
- Configures authentication

### **Phase 3: Django Application Setup**
- Clones your GitHub repository
- Sets up virtual environment
- Installs Python dependencies
- Configures Django settings
- Runs database migrations
- Sets up Gunicorn service

### **Phase 4: Web Server Setup (HTTP Only)**
- Installs and configures Nginx
- Sets up HTTP-only configuration (no SSL)
- Configures rate limiting and security headers
- Sets up static/media file serving
- Configures firewall for HTTP and SSH

### **Phase 5: Security Hardening**
- Configures fail2ban for brute force protection
- Sets up log rotation
- Configures system monitoring
- Applies security best practices

### **Final Steps**
- Creates Django superuser
- Collects static files
- Tests all services
- Generates deployment report

---

## 🔧 **Interactive Configuration**

The script will ask you for:

### **Required Information:**
- **Domain name** (or use IP address)
- **Database credentials** (name, user, password)
- **Django admin credentials** (username, email, password)

### **Auto-Generated:**
- Django secret key
- Random database password (if not provided)
- SSL certificates (for HTTPS version)

---

## 🌐 **After Deployment**

### **Access Your Application:**
- **Main site:** `http://YOUR-SERVER-IP`
- **Admin panel:** `http://YOUR-SERVER-IP/admin/`

### **File Locations:**
- **Application:** `/opt/django-ticketing/app/`
- **Logs:** `/var/log/nginx/` and `/var/log/django-ticketing/`
- **Static files:** `/opt/django-ticketing/app/static/`
- **Media uploads:** `/opt/django-ticketing/app/media/`

### **Service Management:**
```bash
# Check service status
sudo systemctl status nginx
sudo systemctl status gunicorn-django-ticketing
sudo systemctl status postgresql

# Restart services
sudo systemctl restart nginx
sudo systemctl restart gunicorn-django-ticketing

# View logs
sudo tail -f /var/log/nginx/django-ticketing-error.log
sudo journalctl -u gunicorn-django-ticketing -f
```

---

## 🔒 **Security Features**

### **Enabled:**
✅ Rate limiting for login attempts  
✅ Security headers (X-Frame-Options, X-Content-Type-Options, etc.)  
✅ File upload size limits (100MB)  
✅ Attack pattern blocking  
✅ Fail2ban for brute force protection  
✅ Firewall configuration (HTTP + SSH only)  

### **Not Included (HTTP-Only):**
❌ SSL/HTTPS encryption  
❌ HSTS headers  
❌ SSL certificate management  

---

## ⚠️ **Important Notes**

### **HTTP-Only Deployment:**
- Data is transmitted unencrypted
- Suitable for internal networks or development
- For production, consider enabling SSL later

### **Firewall Configuration:**
- Only ports 80 (HTTP) and 22 (SSH) are open
- All other ports are blocked by default

### **File Uploads:**
- Your new **Dropbox-style file upload** interface is fully working
- Supports drag & drop, multiple files, file validation
- 100MB per file limit, 5MB browser validation

---

## 🎯 **Upgrading to HTTPS Later**

If you want to add SSL later:
1. Get a domain name
2. Run the original `04-nginx-setup.sh` script
3. Configure Let's Encrypt certificates

---

## 📊 **Monitoring & Maintenance**

### **Regular Tasks:**
- Monitor disk space: `df -h`
- Check logs: `sudo tail -f /var/log/nginx/django-ticketing-error.log`
- Update system: `sudo apt update && sudo apt upgrade`
- Backup database: `pg_dump django_ticketing > backup.sql`

### **Performance Monitoring:**
- CPU usage: `htop`
- Memory usage: `free -h`
- Service status: `sudo systemctl status nginx gunicorn-django-ticketing postgresql`

---

## 🆘 **Troubleshooting**

### **Common Issues:**

**Application not loading:**
```bash
# Check service status
sudo systemctl status gunicorn-django-ticketing
sudo systemctl status nginx

# Check logs
sudo journalctl -u gunicorn-django-ticketing -n 50
sudo tail -n 50 /var/log/nginx/django-ticketing-error.log
```

**Database connection issues:**
```bash
# Test PostgreSQL
sudo -u postgres psql -c "\l"

# Check Django database connection
cd /opt/django-ticketing/app
sudo -u www-data python3 manage.py dbshell
```

**File upload issues:**
```bash
# Check permissions
ls -la /opt/django-ticketing/app/media/
sudo chown -R www-data:www-data /opt/django-ticketing/app/media/
```

---

## 📞 **Support**

If you encounter issues:
1. Check the deployment log: `/var/log/django-deployment.log`
2. Review the deployment report: `/opt/django-ticketing/DEPLOYMENT_REPORT.md`
3. Check service logs as shown above
4. Verify all services are running

---

**Deployment Type:** HTTP-Only (No SSL)  
**Target OS:** Ubuntu 20.04+ (LTS recommended)  
**Minimum Requirements:** 2GB RAM, 10GB disk space  
**Estimated Deployment Time:** 10-15 minutes  
