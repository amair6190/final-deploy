# SolvIT Ticketing System - Domain Setup Guide

This comprehensive guide will help you properly configure domain access for your SolvIT Ticketing System, both for local network access and external internet access.

## Prerequisites
- A registered domain name (from any domain registrar like Namecheap, GoDaddy, etc.)
- Access to your domain's DNS settings
- Your server has a public IP address for external access (not behind CGNAT)
- Port 80 and 443 forwarded to your server if behind a router

## Common Domain Access Issues

Before proceeding, be aware of these common domain access issues:

1. **DNS Resolution to 127.0.0.1**: If your domain resolves to 127.0.0.1 instead of your actual server IP, only the server itself can access the application through the domain.

2. **Incorrect Binding**: If Gunicorn is bound only to localhost (127.0.0.1), external devices can't connect even with correct DNS.

3. **Missing CSRF Configuration**: If your domain isn't in CSRF_TRUSTED_ORIGINS, form submissions will fail.

4. **Improper Proxy Configuration**: If using Nginx Proxy Manager or another proxy, incorrect header forwarding can cause issues.

## Step 1: Identify Your Server IPs

### For Local Network Access
Your server's local IP address (for access within your network):
```bash
hostname -I | awk '{print $1}'
```

### For Internet Access
Your server's public IP address (for access from the internet):
```bash
sudo ./check-public-ip.sh
```

## Step 2: Configure Your Domain's DNS Settings

### External Domain Access (Internet)

1. Log in to your domain registrar's website (Namecheap, GoDaddy, etc.)
2. Navigate to the DNS management section
3. Create A records pointing to your server's **public** IP address:
   - Type: A
   - Host: @ (or leave blank for root domain)
   - Value: YOUR_PUBLIC_IP (from the check-public-ip.sh script)
   - TTL: 3600 (or automatic)
   
4. Add a second A record for the www subdomain:
   - Type: A
   - Host: www
   - Value: YOUR_PUBLIC_IP

### Local Network Access

For accessing your application within your local network using the domain name:

1. **Option 1: Local DNS Server**
   If you have a local DNS server (like Pi-hole or your router):
   - Add a custom DNS entry for your domain pointing to your server's **local** IP

2. **Option 2: Hosts File on Client Devices**
   On each device that needs to access the application:
   - Edit the hosts file (requires admin/root privileges)
   - Add: `10.0.0.95 support.solvitservices.com www.support.solvitservices.com`
   - Location of hosts file:
     - Windows: `C:\Windows\System32\drivers\etc\hosts`
     - Mac/Linux: `/etc/hosts`

### Verify DNS Resolution

After configuring DNS, verify it's resolving correctly:
```bash
nslookup support.solvitservices.com
```

The output should show your server's IP address, not 127.0.0.1.

If it shows 127.0.0.1, check:
1. Your local `/etc/hosts` file for conflicting entries
2. Your DNS configuration at your registrar
3. Local DNS cache (may need to be flushed)

Wait for DNS propagation (can take from a few minutes to 48 hours)

## Step 3: Configure CSRF Trusted Origins

Django's CSRF protection requires your domain to be explicitly trusted. Without this configuration, form submissions will fail with "CSRF verification failed" errors.

1. Edit your .env file:
```bash
sudo nano /opt/solvit-ticketing/.env
```

2. Add or update the CSRF_TRUSTED_ORIGINS setting:
```
CSRF_TRUSTED_ORIGINS=https://support.solvitservices.com,http://support.solvitservices.com,https://www.support.solvitservices.com,http://www.support.solvitservices.com
```

3. Restart the application for changes to take effect:
```bash
sudo systemctl restart solvit-ticketing
```

## Step 4: Ensure Gunicorn Listens on All Interfaces

A common issue is that Gunicorn only listens on localhost (127.0.0.1) instead of all interfaces, making it inaccessible from other devices.

1. Check the current binding:
```bash
sudo lsof -i :8001
```

2. If you see `127.0.0.1:8001` instead of `*:8001`, run the fix script:
```bash
sudo ./fix_gunicorn_binding.sh
```

This script updates the Gunicorn configuration to listen on all interfaces (0.0.0.0) and restarts the service.

## Step 5: Choose a Domain Configuration Method

You have two options for configuring domain access:

### Option 1: Using the Built-in Domain Setup Script

Run the domain setup script with your domain name:

```bash
cd /home/amair/Desktop/deploy-ticket/solvit-ticketing-system-v2
sudo ./setup-domain.sh yourdomain.com
```

This script will:
1. Update the Django application settings
2. Create Nginx configuration for your domain
3. Set up SSL certificates with Let's Encrypt
4. Configure proper security headers
5. Restart all necessary services

### Option 2: Using Nginx Proxy Manager (NPM)

If you prefer a GUI-based approach or already use Nginx Proxy Manager:

1. **Access Nginx Proxy Manager**:
   - Open your browser and navigate to your NPM interface (typically http://npm-server-ip:81)
   - Log in with your credentials

2. **Create a Proxy Host**:
   - Click on "Proxy Hosts" in the top menu
   - Click "Add Proxy Host"

3. **Configure the Details Tab**:
   - Domain Names: Enter `support.solvitservices.com` (and www.support.solvitservices.com if needed)
   - Scheme: `http`
   - Forward Hostname / IP: Your application server IP (e.g., 10.0.0.95)
   - Forward Port: `8001`
   - Check "Cache Assets" and "Block Common Exploits"

4. **Configure the SSL Tab**:
   - SSL Certificate: Request a new SSL certificate (Let's Encrypt)
   - Force SSL: Enabled
   - HTTP/2 Support: Enabled
   - HSTS Enabled: Enabled

5. **Configure the Advanced Tab**:
   Add this complete configuration:

```
# Headers for CSRF protection
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $host;
proxy_set_header Origin $scheme://$host;

# WebSocket support (if needed)
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";

# Static files
location /static/ {
    proxy_pass http://10.0.0.95:8001/static/;
    expires 30d;
    add_header Cache-Control "public, immutable";
}

# Media files
location /media/ {
    proxy_pass http://10.0.0.95:8001/media/;
    expires 30d;
}

# Increased timeouts for long-running requests
proxy_connect_timeout 120s;
proxy_send_timeout 120s;
proxy_read_timeout 120s;
```

Replace `10.0.0.95` with your actual application server IP.

## Step 6: Test Your Domain Configuration

1. Open a web browser and navigate to:
   - https://support.solvitservices.com

2. Verify SSL is working properly (green lock icon)
3. Test these key functionalities:
   - Login to the system
   - Create a ticket (tests form submission and CSRF)
   - View ticket details
   - Upload a file (if applicable)

## Step 7: Use the Domain Verification Script

We've created a comprehensive domain verification script that will help identify and fix common issues:

```bash
sudo chmod +x verify_domain_setup.sh
sudo ./verify_domain_setup.sh
```

This script will check:
- DNS resolution
- Direct application accessibility
- CSRF configuration
- Common domain configuration issues

Follow any recommendations provided by the script to resolve identified issues.

## Troubleshooting Common Domain Issues

### ERR_CONNECTION_REFUSED

**Problem**: Browser shows "ERR_CONNECTION_REFUSED" when accessing your domain

**Possible causes and solutions**:
1. **DNS issue**: Verify your domain points to the correct IP with `nslookup support.solvitservices.com`
2. **Gunicorn binding issue**: Run `sudo ./fix_gunicorn_binding.sh`
3. **Service not running**: Check with `sudo systemctl status solvit-ticketing`
4. **Firewall blocking**: Verify with `sudo ufw status`

### CSRF Verification Failed

**Problem**: You get "CSRF verification failed" when submitting forms

**Solutions**:
1. Check your `.env` file to ensure your domain is in CSRF_TRUSTED_ORIGINS:
   ```bash
   grep CSRF_TRUSTED_ORIGINS /opt/solvit-ticketing/.env
   ```
2. If using NPM, verify that the correct headers are in the Advanced tab configuration
3. Try clearing browser cookies and cache

### DNS Shows 127.0.0.1

**Problem**: `nslookup support.solvitservices.com` shows 127.0.0.1

**Solutions**:
1. Check your local `/etc/hosts` file:
   ```bash
   grep support.solvitservices.com /etc/hosts
   ```
2. Update any entries to use your server's actual IP instead of 127.0.0.1
3. If no entry exists, update your DNS records at your domain registrar

### Other Troubleshooting Resources

- **DNS Propagation**: Use https://dnschecker.org to verify your DNS records globally
- **SSL Certificates**: `sudo certbot certificates` to check certificate status
- **Nginx Configuration**: `sudo nginx -t` to check for syntax errors
- **Logs**:
  - Application logs: `sudo journalctl -u solvit-ticketing -f`
  - Nginx logs: `sudo tail -f /var/log/nginx/solvit-error.log`
  - NPM logs: Check through the NPM interface

## Security Considerations

1. **Regular Updates**: Keep your system and application updated
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Firewall Configuration**: Ensure only necessary ports are open
   ```bash
   sudo ufw status
   ```

3. **SSL Certificate Renewal**: Let's Encrypt certificates expire after 90 days
   ```bash
   sudo certbot renew --dry-run
   ```

4. **Application Security**: Regularly check for application vulnerabilities
   ```bash
   # Update Django and dependencies
   cd /home/amair/Desktop/deploy-ticket/solvit-ticketing-system-v2
   source venv/bin/activate
   pip install --upgrade -r requirements.txt
   ```

## Maintenance

### Backup Your Database
Regularly backup your PostgreSQL database:
```bash
# Replace with your database name
pg_dump -U solvit_user solvit_ticketing > backup_$(date +%Y%m%d).sql
```

### Monitor System Resources
Check system resource usage:
```bash
htop
```

### Rotate Logs
Configure log rotation to prevent disk space issues:
```bash
sudo nano /etc/logrotate.d/solvit-ticketing
```
