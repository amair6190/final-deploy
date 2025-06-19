# Setting up Domain Access for SolvIT Ticketing System

## Step 1: Set up DNS Records at Your Domain Provider
1. Log in to your domain registrar (like Namecheap, GoDaddy, etc.)
2. Create an A record pointing to your server's public IP address:
   - Type: A
   - Host: @ (or subdomain like "tickets" or "support")
   - Value: YOUR_SERVER_PUBLIC_IP (find this using `curl ifconfig.me`)
   - TTL: Automatic or 3600

## Step 2: Update Allowed Hosts in Django Settings
1. Edit your .env file to add your domain to ALLOWED_HOSTS:

```bash
ALLOWED_HOSTS=127.0.0.1,localhost,yourdomain.com,www.yourdomain.com
```

## Step 3: Configure Nginx for Your Domain
1. Create a new Nginx configuration file for your domain
2. Set up SSL with Let's Encrypt for secure HTTPS connections
3. Configure proper proxy settings to the running Gunicorn instance

## Step 4: Test Your Domain Setup
1. Verify DNS propagation
2. Check SSL certificate installation
3. Test the application through the domain

Follow the detailed steps below to complete the setup.
