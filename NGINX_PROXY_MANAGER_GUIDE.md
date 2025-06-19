# Setting up SolvIT Ticketing System with Nginx Proxy Manager

This guide will help you configure your SolvIT Ticketing System to work with Nginx Proxy Manager (NPM), a GUI-based tool for managing Nginx proxies.

## Prerequisites

1. Your SolvIT Ticketing System is deployed and running on your server
2. You have Nginx Proxy Manager installed and accessible
3. You have a domain name pointed to your Nginx Proxy Manager's IP address

## Step 1: Prepare Your Django Application

Your Django application has already been configured with:

1. CSRF trusted origins for your domain
2. Allowed hosts including your domain

## Step 2: Configure Nginx Proxy Manager

1. **Log in to Nginx Proxy Manager**:
   - Open your browser and navigate to your Nginx Proxy Manager dashboard
   - Default credentials are admin@example.com / changeme (if you haven't changed them)

2. **Create a New Proxy Host**:
   - Click on "Proxy Hosts" in the top menu
   - Click "Add Proxy Host" button

3. **Configure the Proxy Host**:

   **Details Tab**:
   - Domain Names: `support.solvitservices.com` (add both with and without www)
   - Scheme: `http`
   - Forward Hostname / IP: [Your application server's IP address]
   - Forward Port: `8001`
   - Cache Assets: Enabled (recommended)
   - Block Common Exploits: Enabled (recommended)

   **SSL Tab**:
   - SSL Certificate: Request a new SSL certificate (Let's Encrypt)
   - Force SSL: Enabled
   - HTTP/2 Support: Enabled
   - HSTS Enabled: Enabled
   - HSTS Subdomains: Enabled

   **Advanced Tab**:
   - Custom Nginx Configuration:
   ```
   # Add these headers for CSRF protection
   proxy_set_header X-Forwarded-Proto $scheme;
   proxy_set_header X-Forwarded-Host $host;
   proxy_set_header Origin $scheme://$host;
   
   # Static files location
   location /static/ {
       alias /home/amair/Desktop/deploy-ticket/solvit-ticketing-system-v2/staticfiles/;
       expires 30d;
       add_header Cache-Control "public, immutable";
   }
   
   # Media files location
   location /media/ {
       alias /home/amair/Desktop/deploy-ticket/solvit-ticketing-system-v2/media/;
       expires 30d;
   }
   ```

4. **Save the configuration**:
   - Click "Save" to create the proxy host

## Step 3: Configure Static and Media Files (Optional)

If your Nginx Proxy Manager is running on a different server than your Django application, you'll need to make static and media files accessible. You have two options:

### Option 1: Copy Static Files to Proxy Server
```bash
# Run on your application server to sync files to proxy server
rsync -avz /home/amair/Desktop/deploy-ticket/solvit-ticketing-system-v2/staticfiles/ user@proxy-server:/path/to/staticfiles/
rsync -avz /home/amair/Desktop/deploy-ticket/solvit-ticketing-system-v2/media/ user@proxy-server:/path/to/media/
```

### Option 2: Serve Static Files Directly from Django
Remove the static and media file locations from the Nginx Proxy Manager custom configuration, and let Django serve these files.

## Step 4: Configure Firewall Rules

Make sure your application server allows connections from your Nginx Proxy Manager:

```bash
# On your application server
sudo ufw allow from PROXY_MANAGER_IP to any port 8001
```

Replace `PROXY_MANAGER_IP` with the IP address of your Nginx Proxy Manager server.

## Step 5: Test Your Setup

1. Visit your domain in a browser:
   ```
   https://support.solvitservices.com
   ```

2. Try logging in to verify CSRF protection is working correctly.

## Troubleshooting

### CSRF Verification Failed

If you see "CSRF verification failed" errors:

1. **Check your Django settings**:
   Make sure `.env` has the correct CSRF_TRUSTED_ORIGINS:
   ```
   CSRF_TRUSTED_ORIGINS=https://support.solvitservices.com,https://www.support.solvitservices.com
   ```

2. **Check Nginx Proxy Manager configuration**:
   - Verify the custom Nginx configuration includes the required headers
   - Try adding additional headers in the Advanced tab:
   ```
   proxy_set_header X-Real-IP $remote_addr;
   proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
   ```

3. **Temporarily relax security settings**:
   Edit your `.env` file:
   ```
   SECURE_SSL_REDIRECT=False
   CSRF_COOKIE_SECURE=False
   SESSION_COOKIE_SECURE=False
   ```

### Connection Refused

If NPM can't connect to your Django application:

1. Check if your Django application is running:
   ```bash
   sudo systemctl status solvit-ticketing
   ```

2. Verify firewall settings:
   ```bash
   sudo ufw status
   ```

3. Test direct connection to your application:
   ```bash
   curl http://localhost:8001
   ```

### Static Files Not Loading

If your site loads but is missing styles or images:

1. Check if static files are accessible from NPM server
2. Consider using Option 2 (letting Django serve static files)
3. Check file permissions on static directories

## Maintenance

For future updates or maintenance:

1. When updating your Django application:
   ```bash
   sudo systemctl restart solvit-ticketing
   ```

2. If you've changed static files, update them on your proxy server if needed:
   ```bash
   rsync -avz /home/amair/Desktop/deploy-ticket/solvit-ticketing-system-v2/staticfiles/ user@proxy-server:/path/to/staticfiles/
   ```
