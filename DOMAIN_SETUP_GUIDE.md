# SolvIT Ticketing System - External Domain Access Guide

This guide will help you make your locally deployed SolvIT Ticketing System accessible from the internet using your domain name.

## Prerequisites
- A registered domain name (from any domain registrar like Namecheap, GoDaddy, etc.)
- Access to your domain's DNS settings
- Your server has a public IP address (not behind CGNAT)
- Port 80 and 443 forwarded to your server if behind a router

## Step 1: Check Your Server's Public IP

Run the provided script to determine your server's public IP address:

```bash
sudo ./check-public-ip.sh
```

## Step 2: Configure Your Domain's DNS Settings

1. Log in to your domain registrar's website
2. Navigate to the DNS management section
3. Create A records pointing to your server's IP address:
   - Type: A
   - Host: @ (or leave blank for root domain)
   - Value: YOUR_SERVER_IP (from the previous step)
   - TTL: 3600 (or automatic)
   
4. Add a second A record for the www subdomain:
   - Type: A
   - Host: www
   - Value: YOUR_SERVER_IP
   - TTL: 3600 (or automatic)

5. Wait for DNS propagation (can take from a few minutes to 48 hours)

## Step 3: Configure Your Server for Domain Access

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

## Step 4: Test Your Domain Configuration

1. Open a web browser and navigate to:
   - https://yourdomain.com

2. Verify SSL is working properly (green lock icon)
3. Check all functionality of your ticketing system

## Troubleshooting

### DNS Issues
- Use https://dnschecker.org to verify your DNS records have propagated
- If DNS records are not updating, contact your domain registrar

### SSL Certificate Issues
- Run `sudo certbot certificates` to check certificate status
- Run `sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com` to attempt certificate renewal

### Nginx Configuration Issues
- Check for errors: `sudo nginx -t`
- View Nginx logs: `sudo tail -f /var/log/nginx/solvit-error.log`
- Restart Nginx: `sudo systemctl restart nginx`

### Application Issues
- Check application logs: `sudo journalctl -u solvit-ticketing -f`
- Restart application: `sudo systemctl restart solvit-ticketing`

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
