# Setting up SolvIT Ticketing System with Your Nginx Proxy Server

This guide explains how to use your existing Nginx proxy server to serve your SolvIT Ticketing System with a domain name.

## Prerequisites

1. Your SolvIT Ticketing System is already deployed and running on your server
2. You have a domain name (e.g., support.solvitservices.com) pointing to your proxy server's IP
3. Your proxy server has Nginx installed
4. You have SSL certificates (recommended)

## Step 1: Configure Your Proxy Server

1. Copy the provided Nginx configuration to your proxy server:

   ```bash
   # On your proxy server
   sudo cp /path/to/nginx-proxy-config.conf /etc/nginx/sites-available/support.solvitservices.com
   ```

2. Edit the configuration to replace `YOUR_MAIN_SERVER_IP` with the actual IP address of the server running your SolvIT application:

   ```bash
   sudo nano /etc/nginx/sites-available/support.solvitservices.com
   ```

   Find and replace:
   ```
   proxy_pass http://YOUR_MAIN_SERVER_IP:8001;
   ```
   
   With your actual server IP:
   ```
   proxy_pass http://192.168.1.100:8001;  # Replace with your actual server IP
   ```

3. If using SSL (recommended), ensure the certificate paths are correct:

   ```
   ssl_certificate /etc/letsencrypt/live/support.solvitservices.com/fullchain.pem;
   ssl_certificate_key /etc/letsencrypt/live/support.solvitservices.com/privkey.pem;
   ```

   If you don't have SSL certificates yet, you can obtain them using Let's Encrypt:

   ```bash
   sudo apt install certbot python3-certbot-nginx
   sudo certbot --nginx -d support.solvitservices.com -d www.support.solvitservices.com
   ```

4. Enable the site and reload Nginx:

   ```bash
   sudo ln -s /etc/nginx/sites-available/support.solvitservices.com /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl reload nginx
   ```

## Step 2: Configure Firewall on Application Server

Ensure that your application server allows connections from your proxy server:

```bash
# On your application server
sudo ufw allow from PROXY_SERVER_IP to any port 8001
```

Replace `PROXY_SERVER_IP` with the IP address of your proxy server.

## Step 3: Update Django CSRF Settings

Your Django settings have already been updated with:

1. Your domain added to ALLOWED_HOSTS
2. CSRF_TRUSTED_ORIGINS setting added

You can confirm these changes are working by checking the `.env` file and `settings_production.py`.

## Step 4: Test Your Configuration

1. Restart your Django application:

   ```bash
   sudo systemctl restart solvit-ticketing
   ```

2. Visit your domain in a browser:

   ```
   https://support.solvitservices.com
   ```

## Troubleshooting

### CSRF Verification Failed

If you see "CSRF verification failed" errors:

1. Check that your domain is correctly set in CSRF_TRUSTED_ORIGINS in the `.env` file
2. Ensure your Nginx proxy is correctly passing the `Host`, `Origin`, and `X-Forwarded-*` headers
3. Clear your browser cookies and try again

### 502 Bad Gateway

This usually means your proxy can't reach the application server:

1. Verify that the application server IP is correct in your Nginx proxy configuration
2. Check that port 8001 is accessible from your proxy server
3. Ensure the Gunicorn service is running: `sudo systemctl status solvit-ticketing`
4. Check the Nginx error logs on your proxy server

### SSL Certificate Issues

If you see SSL warnings:

1. Verify that your SSL certificates are correctly installed
2. Check that the certificate paths in Nginx configuration are correct
3. Ensure your certificates are not expired

### Static Files Not Loading

If your site loads but is missing styles or images:

1. Verify that the paths to static and media files are correct in your Nginx configuration
2. Ensure that the static files are accessible from your proxy server
3. Check permissions on the static files directories
