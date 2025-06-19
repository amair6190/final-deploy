# SolvIT Ticketing System - Deployment Options

This document outlines the different deployment options available for setting up your SolvIT Ticketing System on your Ubuntu server (IP: 10.0.0.18).

## Option 1: Automated Deployment Script (Recommended)

We've created a comprehensive deployment script that automates the entire process of setting up the SolvIT Ticketing System on your Ubuntu server.

### Features:
- Full server setup from scratch
- Database creation and configuration
- Python environment setup
- Django application deployment
- Nginx and Gunicorn configuration
- Firewall setup
- SSL certificate installation (optional)
- Comprehensive deployment report

### Usage:
```bash
# First, copy the script to your target server
scp deploy_to_new_server.sh user@10.0.0.18:/home/user/

# SSH into your server
ssh user@10.0.0.18

# Run the script with sudo
sudo bash deploy_to_new_server.sh
```

The script is interactive and will prompt you for necessary information like database credentials and admin user details.

## Option 2: Manual Deployment (Step-by-Step)

If you prefer more control over the deployment process, or want to understand the steps involved, we've provided a detailed manual deployment guide.

### Contents:
- System setup and package installation
- Database configuration
- Application file transfer
- Django setup and configuration
- Gunicorn and Nginx configuration
- Firewall and security setup
- SSL certificate installation

The manual guide is available in the file: `MANUAL_DEPLOYMENT_GUIDE.md`

## Option 3: Using Nginx Proxy Manager

If you already have Nginx Proxy Manager installed on your server or on another server, you can use it to proxy requests to your SolvIT Ticketing System.

### Deployment flow:
1. Deploy the SolvIT Ticketing System using Option 1 or Option 2
2. Configure Nginx Proxy Manager to proxy requests to your application

Detailed instructions for setting up Nginx Proxy Manager are available in:
- `NPM_VISUAL_GUIDE.md`
- `NGINX_PROXY_MANAGER_GUIDE.md`

## Choosing the Right Option

- **Option 1 (Automated Script)**: Best for quick deployment if you're comfortable with automated scripts.
- **Option 2 (Manual Deployment)**: Best if you want to understand each step or need to customize the deployment.
- **Option 3 (Nginx Proxy Manager)**: Best if you already have a proxy server setup or want to manage multiple applications through a single interface.

## Requirements for All Options

- Ubuntu Server 20.04 or 22.04 LTS
- Root or sudo access
- Internet connection
- Your domain (support.solvitservices.com) pointed to your server IP (10.0.0.18)

## Post-Deployment Verification

After deployment (regardless of which option you choose), verify that:

1. You can access the application at http://10.0.0.18:8001/
2. You can access the application through your domain: http://support.solvitservices.com/
3. You can log in to the admin interface: http://support.solvitservices.com/admin/
4. Form submissions work properly (test CSRF protection)
5. Static files load correctly (CSS, JavaScript, images)

## Support and Troubleshooting

If you encounter issues during deployment:

1. Check the application logs: `sudo journalctl -u solvit-ticketing -f`
2. Check the Nginx logs: `sudo tail -f /var/log/nginx/solvit-error.log`
3. Verify that services are running: `sudo systemctl status solvit-ticketing nginx`
4. Test direct access to the application: `curl -I http://127.0.0.1:8001/`
