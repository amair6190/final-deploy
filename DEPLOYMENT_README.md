# SolvIT Django Ticketing System - Ubuntu Server Deployment

## 🚀 Quick Deployment

This repository contains a complete IT ticketing system built with Django, ready for deployment on Ubuntu Server.

### Prerequisites
- Ubuntu Server 20.04/22.04 LTS
- Root or sudo access
- Internet connection

### Deployment Steps

1. **Clean up old files (optional):**
   ```bash
   sudo ./cleanup-scripts.sh
   ```

2. **Deploy the application:**
   ```bash
   sudo ./deploy-ubuntu-server.sh
   ```

3. **Access your application:**
   - Main site: `http://your-server-ip/`
   - Admin panel: `http://your-server-ip/admin/`
   - Default admin login: `admin / SolvIT@2024`

### What the deployment script does:

✅ **System Setup** - Updates Ubuntu and installs required packages  
✅ **Database Setup** - Configures PostgreSQL with secure credentials  
✅ **Django Application** - Sets up virtual environment and installs dependencies  
✅ **Web Server** - Configures Nginx as reverse proxy  
✅ **Application Server** - Sets up Gunicorn with systemd service  
✅ **Security** - Enables firewall and fail2ban  
✅ **SSL Ready** - Prepared for HTTPS certificate installation  

### Management Commands

```bash
# Check application status
systemctl status solvit-ticketing

# Restart application
systemctl restart solvit-ticketing

# View application logs
journalctl -u solvit-ticketing -f

# Check web server status
systemctl status nginx

# Restart web server
systemctl restart nginx
```

### Configuration Files

- **Application**: `/opt/solvit-ticketing/`
- **Nginx Config**: `/etc/nginx/sites-available/solvit-ticketing`
- **Service Config**: `/etc/systemd/system/solvit-ticketing.service`
- **Logs**: `/var/log/solvit-ticketing.log`
- **Deployment Info**: `/opt/solvit-ticketing/DEPLOYMENT_INFO.txt`

### Production Setup

For production use:

1. **Update domain name** in Nginx configuration
2. **Add SSL certificate** (Let's Encrypt recommended)
3. **Update ALLOWED_HOSTS** in Django settings
4. **Setup database backups**
5. **Configure monitoring**

### Troubleshooting

- Check logs: `journalctl -u solvit-ticketing -f`
- Test Nginx config: `nginx -t`
- Restart services: `systemctl restart solvit-ticketing nginx`
- Check firewall: `ufw status`

### Features

- 🎫 **Ticket Management** - Create, assign, and track support tickets
- 👥 **User Management** - Customer and agent accounts
- 📧 **Email Notifications** - Automated ticket updates
- 📱 **Responsive Design** - Works on desktop and mobile
- 🔒 **Secure** - Built-in security features
- 📊 **Reporting** - Track ticket metrics and performance

### Support

- Check deployment info: `cat /opt/solvit-ticketing/DEPLOYMENT_INFO.txt`
- Application logs: `tail -f /var/log/solvit-ticketing.log`
- Database connection: Use credentials from deployment info

---

**Your SolvIT Django Ticketing System will be ready in just a few minutes!** 🎉
