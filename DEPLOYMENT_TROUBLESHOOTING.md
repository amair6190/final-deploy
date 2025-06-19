# SolvIT Ticketing System - Deployment Troubleshooting Guide

This document provides solutions to common deployment issues with the SolvIT Ticketing System.

## Common Issues and Solutions

### ERR_CONNECTION_REFUSED

**Problem**: You can't connect to the application from other machines, seeing an "ERR_CONNECTION_REFUSED" error in your browser.

**Cause**: Gunicorn is configured to listen only on localhost (127.0.0.1) instead of all interfaces (0.0.0.0).

**Solution**: 
1. Run the fix script:
   ```bash
   sudo ./fix_gunicorn_binding.sh
   ```

2. Or manually update the binding:
   ```bash
   sudo sed -i 's/--bind 127.0.0.1:8001/--bind 0.0.0.0:8001/' /etc/systemd/system/solvit-ticketing.service
   sudo systemctl daemon-reload
   sudo systemctl restart solvit-ticketing
   ```

**Prevention**: See [PREVENTING_CONNECTION_ISSUES.md](PREVENTING_CONNECTION_ISSUES.md) for details on how we've updated our scripts to prevent this issue.

### CSRF Verification Failed

**Problem**: Form submissions fail with a "CSRF verification failed" error.

**Cause**: CSRF trusted origins are not correctly configured or the proxy is not forwarding the correct headers.

**Solution**:
1. Check your .env file and ensure the domain is in CSRF_TRUSTED_ORIGINS:
   ```
   CSRF_TRUSTED_ORIGINS=https://yourdomain.com,http://yourdomain.com
   ```

2. If using Nginx Proxy Manager, add these headers in the Advanced tab:
   ```
   proxy_set_header Host $host;
   proxy_set_header X-Real-IP $remote_addr;
   proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
   proxy_set_header X-Forwarded-Proto $scheme;
   proxy_set_header Origin $scheme://$host;
   ```

See [TROUBLESHOOTING_CSRF.md](TROUBLESHOOTING_CSRF.md) for more details.

### Static Files Not Loading

**Problem**: The application loads but is missing styles, images, or other static content.

**Solution**:
1. Check if static files were collected:
   ```bash
   ls /opt/solvit-ticketing/staticfiles/
   ```

2. If empty, run collectstatic:
   ```bash
   cd /opt/solvit-ticketing
   source venv/bin/activate
   python manage.py collectstatic --noinput
   ```

3. Verify Nginx configuration has the correct path:
   ```
   location /static/ {
       alias /opt/solvit-ticketing/staticfiles/;
   }
   ```

### Database Connection Issues

**Problem**: Application shows database errors or fails to start with database-related messages.

**Solution**:
1. Verify PostgreSQL is running:
   ```bash
   sudo systemctl status postgresql
   ```

2. Check if the database exists:
   ```bash
   sudo -u postgres psql -c "\l" | grep solvit
   ```

3. Verify database user and permissions:
   ```bash
   sudo -u postgres psql -c "\du" | grep solvit
   ```

4. Check connection settings in .env file:
   ```bash
   grep DATABASE_URL /opt/solvit-ticketing/.env
   ```

## Service Management

### Checking Service Status

```bash
# Check Gunicorn status
sudo systemctl status solvit-ticketing

# Check Nginx status
sudo systemctl status nginx

# View Gunicorn logs
sudo journalctl -u solvit-ticketing -f

# View Nginx logs
sudo tail -f /var/log/nginx/solvit-error.log
```

### Restarting Services

```bash
# Restart Gunicorn
sudo systemctl restart solvit-ticketing

# Restart Nginx
sudo systemctl restart nginx
```

## Firewall Issues

If you suspect firewall issues:

```bash
# Check firewall status
sudo ufw status

# Allow necessary ports if they're not already allowed
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8001/tcp
```

## Additional Resources

- For in-depth connection issue prevention: [PREVENTING_CONNECTION_ISSUES.md](PREVENTING_CONNECTION_ISSUES.md)
- For CSRF issues: [TROUBLESHOOTING_CSRF.md](TROUBLESHOOTING_CSRF.md)
- For Nginx Proxy Manager setup: [NGINX_PROXY_MANAGER_GUIDE.md](NGINX_PROXY_MANAGER_GUIDE.md)
