# Nginx Proxy Manager Troubleshooting Guide

## Problem Solved: Gunicorn Now Listening on All Interfaces

We identified and fixed the main issue - Gunicorn was only listening on the localhost interface (127.0.0.1), which meant it wasn't accessible from other machines. We've updated the configuration to listen on all interfaces (0.0.0.0).

## Testing Direct Access

You should now be able to access your application directly:

1. From your server: `http://127.0.0.1:8001`
2. From other machines on your network: `http://10.0.0.95:8001`

## Setting Up Nginx Proxy Manager

Now that the application is accessible, you can set up Nginx Proxy Manager:

### Step 1: Access Nginx Proxy Manager

Log in to your Nginx Proxy Manager interface (typically at http://YOUR_NPM_SERVER:81).

### Step 2: Create a New Proxy Host

1. Click "Proxy Hosts" in the top menu
2. Click "Add Proxy Host"
3. Fill in these details:

**Domain Tab:**
- Domain Names: `support.solvitservices.com` (and www.support.solvitservices.com if needed)
- Scheme: `http`
- Forward Hostname / IP: `10.0.0.95` (your SolvIT server IP)
- Forward Port: `8001`
- Cache Assets: Enabled
- Block Common Exploits: Enabled

**SSL Tab:**
- SSL Certificate: Request a new SSL Certificate (Let's Encrypt)
- Force SSL: Enabled
- HTTP/2 Support: Enabled
- HSTS Enabled: Enabled

**Advanced Tab:**
Add this custom configuration:
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
```

### Step 3: Save and Test

1. Save your proxy host configuration
2. Access `https://support.solvitservices.com`

## Troubleshooting Domain Access

If direct IP:port access works but domain access still fails:

### 1. DNS Configuration
Ensure your domain points to the Nginx Proxy Manager's IP address (not the SolvIT server IP).

Check your DNS configuration with:
```bash
nslookup support.solvitservices.com
```

### 2. NPM Server Firewall
Make sure ports 80 and 443 are open on your Nginx Proxy Manager server:
```bash
sudo ufw status
```

### 3. SSL Certificate Issues
If you see SSL errors, it might be that:
- Let's Encrypt couldn't validate your domain
- The domain doesn't point to the NPM server
- NPM doesn't have permission to create/manage certificates

### 4. Nginx Proxy Manager Logs
Check NPM logs for errors:
- Access the Nginx Proxy Manager UI
- Click on the proxy host 
- Click "Access Logs" or "Error Logs"

## Additional Configuration Options

### Using Host Headers (if DNS is not configured)

If your DNS is not yet configured, you can test using host headers:
1. Add the domain to your local hosts file:
   ```
   10.0.0.95 support.solvitservices.com
   ```
2. Access the site in your browser

### Remote Access Testing

Use an online tool like https://check-host.net/ to test if your domain is accessible from the internet.

## Final Steps

Once everything is working:

1. Ensure your Django settings have the correct CSRF trusted origins
2. Consider setting up automatic backups for your Nginx Proxy Manager configuration
3. Monitor your access logs for any unusual activity
