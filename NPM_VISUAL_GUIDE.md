# Nginx Proxy Manager - Visual Setup Guide for SolvIT Ticketing System

This guide provides a visual walkthrough for setting up your SolvIT Ticketing System with Nginx Proxy Manager.

## Step 1: Access the Nginx Proxy Manager Dashboard

Open your browser and navigate to your Nginx Proxy Manager UI (typically at http://YOUR_NPM_IP:81).

![Nginx Proxy Manager Login](https://i.imgur.com/JsKgxX4.png)

Default login credentials (if you haven't changed them):
- Email: admin@example.com
- Password: changeme

## Step 2: Create a New Proxy Host

Click on "Proxy Hosts" in the top menu, then click "Add Proxy Host".

![Add Proxy Host](https://i.imgur.com/V8u7z2d.png)

## Step 3: Configure the Details Tab

Fill in the following information:

![Proxy Host Details](https://i.imgur.com/MJ13Htx.png)

- Domain Names: `support.solvitservices.com www.support.solvitservices.com`
- Scheme: `http`
- Forward Hostname / IP: `10.0.0.95` (your SolvIT application server IP)
- Forward Port: `8001` (your Gunicorn port)
- Check "Cache Assets" and "Block Common Exploits"

> **Note:** We've updated your Gunicorn configuration to listen on all interfaces (0.0.0.0) instead of just localhost (127.0.0.1), which was preventing access from other machines.

## Step 4: Configure SSL Settings

Switch to the SSL tab and configure SSL:

![SSL Configuration](https://i.imgur.com/FrvfnJq.png)

- Select "Request a new SSL Certificate"
- Check "Force SSL", "HTTP/2 Support", "HSTS Enabled", and "HSTS Subdomains"
- Enter your email address for Let's Encrypt notifications
- Agree to the Terms of Service

## Step 5: Add Custom Nginx Configuration

Switch to the Advanced tab:

![Advanced Configuration](https://i.imgur.com/XqRxpJZ.png)

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
```

## Step 6: Save the Configuration

Click "Save" to create the proxy host.

## Step 7: Verify the Setup

Your new proxy host should appear in the list:

![Proxy Host List](https://i.imgur.com/YsRsmB1.png)

## Step 8: Test Your Domain

Open your browser and navigate to your domain (https://support.solvitservices.com).

If everything is set up correctly, you should see your SolvIT Ticketing System running with a secure connection.

![Successful Setup](https://i.imgur.com/RZyz0ML.png)

## Troubleshooting

If you encounter issues, check the "Access Lists" and "Logs" sections in Nginx Proxy Manager for error details:

![Logs Section](https://i.imgur.com/WgRdQWs.png)

## Next Steps

Remember to:
1. Change your Nginx Proxy Manager default password
2. Set up regular backups of your NPM configuration
3. Configure email settings for SSL certificate renewal notifications
