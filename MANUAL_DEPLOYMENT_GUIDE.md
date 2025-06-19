# Manual Deployment Guide for SolvIT Ticketing System
# Ubuntu Server IP: 10.0.0.18

This guide provides manual step-by-step instructions for deploying the SolvIT Ticketing System to your Ubuntu server.

## Prerequisites
- Ubuntu Server 20.04/22.04 LTS installed on 10.0.0.18
- Root or sudo access to the server
- Your domain (support.solvitservices.com) pointed to 10.0.0.18

## Step 1: Update System Packages
```bash
sudo apt update
sudo apt upgrade -y
```

## Step 2: Install Required Dependencies
```bash
sudo apt install -y python3 python3-pip python3-venv postgresql postgresql-contrib nginx certbot python3-certbot-nginx git curl ufw fail2ban
```

## Step 3: Set Up PostgreSQL Database
```bash
# Log in to PostgreSQL
sudo -u postgres psql

# Create database user and set password
CREATE USER solvit_user WITH PASSWORD 'YourStrongPassword';
ALTER USER solvit_user CREATEDB;

# Create database
CREATE DATABASE solvit_ticketing OWNER solvit_user;

# Exit PostgreSQL
\q
```

## Step 4: Create Application Directory and System User
```bash
# Create directory
sudo mkdir -p /opt/solvit-ticketing

# Create system user
sudo useradd -r -d /opt/solvit-ticketing -s /bin/false solvit
```

## Step 5: Copy Application Files
Option 1: From your existing server
```bash
# On your current server (10.0.0.95)
sudo rsync -avz /home/amair/Desktop/deploy-ticket/solvit-ticketing-system-v2/ root@10.0.0.18:/opt/solvit-ticketing/
```

Option 2: From Git repository (if available)
```bash
# On the target server (10.0.0.18)
cd /opt/solvit-ticketing
sudo git clone https://github.com/yourusername/solvit-ticketing-system.git .
```

## Step 6: Set Up Python Environment
```bash
# Create virtual environment
cd /opt/solvit-ticketing
sudo python3 -m venv venv
sudo source venv/bin/activate

# Install dependencies
sudo pip install --upgrade pip
sudo pip install -r requirements.txt
sudo pip install gunicorn psycopg2-binary python-dotenv django-jazzmin
```

## Step 7: Create Environment Configuration
Create a `.env` file in `/opt/solvit-ticketing/`:

```bash
sudo nano /opt/solvit-ticketing/.env
```

Add the following content:
```
DEBUG=False
SECRET_KEY=your_generated_secret_key
ALLOWED_HOSTS=127.0.0.1,localhost,10.0.0.18,support.solvitservices.com,www.support.solvitservices.com
DATABASE_URL=postgres://solvit_user:YourStrongPassword@localhost/solvit_ticketing
SECURE_SSL_REDIRECT=False
CSRF_TRUSTED_ORIGINS=http://127.0.0.1:8001,http://10.0.0.18:8001,https://support.solvitservices.com,http://support.solvitservices.com
ADMIN_URL=admin/
```

## Step 8: Update Django Settings for CSRF
Edit the settings_production.py file:

```bash
sudo nano /opt/solvit-ticketing/it_ticketing_system/settings_production.py
```

Add after the CSRF settings:
```python
# CSRF Trusted Origins (for cross-origin requests with domains)
CSRF_TRUSTED_ORIGINS = env.list("CSRF_TRUSTED_ORIGINS", default=[
    "https://support.solvitservices.com",
    "http://support.solvitservices.com",
    "http://10.0.0.18:8001",
])
```

## Step 9: Run Django Migrations and Setup
```bash
# Set environment variable
export DJANGO_SETTINGS_MODULE=it_ticketing_system.settings_production

# Run migrations
sudo python manage.py migrate

# Collect static files
sudo python manage.py collectstatic --noinput

# Create superuser
sudo python manage.py createsuperuser
```

## Step 10: Set Permissions
```bash
sudo chown -R solvit:solvit /opt/solvit-ticketing
```

## Step 11: Create Gunicorn systemd Service
Create a systemd service file:

```bash
sudo nano /etc/systemd/system/solvit-ticketing.service
```

Add the following content:
```
[Unit]
Description=SolvIT Django Ticketing System
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=notify
User=solvit
Group=solvit
RuntimeDirectory=solvit-ticketing
WorkingDirectory=/opt/solvit-ticketing
Environment="PATH=/opt/solvit-ticketing/venv/bin"
Environment="DJANGO_SETTINGS_MODULE=it_ticketing_system.settings_production"
ExecStart=/opt/solvit-ticketing/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:8001 --timeout 60 --keep-alive 2 --max-requests 1000 it_ticketing_system.wsgi:application
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Enable and start the service:
```bash
sudo systemctl daemon-reload
sudo systemctl start solvit-ticketing
sudo systemctl enable solvit-ticketing
```

## Step 12: Configure Nginx
Create a Nginx configuration file:

```bash
sudo nano /etc/nginx/sites-available/solvit
```

Add the following content:
```
server {
    listen 80;
    server_name 10.0.0.18 support.solvitservices.com www.support.solvitservices.com;

    # Static files
    location /static/ {
        alias /opt/solvit-ticketing/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Media files
    location /media/ {
        alias /opt/solvit-ticketing/media/;
        expires 30d;
    }

    # For Let's Encrypt certificate validation
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Proxy Django application requests
    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Origin $scheme://$host;
        
        # WebSocket support (if needed)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeout settings
        proxy_connect_timeout 75s;
        proxy_send_timeout 75s;
        proxy_read_timeout 90s;
    }

    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    
    # Logs
    access_log /var/log/nginx/solvit-access.log;
    error_log /var/log/nginx/solvit-error.log;
}
```

Enable the site and restart Nginx:
```bash
sudo ln -sf /etc/nginx/sites-available/solvit /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx
```

## Step 13: Configure Firewall
```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw allow 8001/tcp comment "SolvIT Django App"
sudo ufw enable
```

## Step 14: Set Up SSL Certificate (Optional)
```bash
sudo certbot --nginx -d support.solvitservices.com -d www.support.solvitservices.com
```

## Step 15: Test Your Deployment
1. Test directly with IP:
   ```
   http://10.0.0.18:8001/
   ```

2. Test with domain:
   ```
   http://support.solvitservices.com/
   ```

3. Test admin access:
   ```
   http://support.solvitservices.com/admin/
   ```

## Troubleshooting

### Service not starting
Check the service logs:
```bash
sudo journalctl -u solvit-ticketing -f
```

### Cannot access application
Check Nginx logs:
```bash
sudo tail -f /var/log/nginx/solvit-error.log
```

### Database connection issues
Verify PostgreSQL is running:
```bash
sudo systemctl status postgresql
```

Check database connection:
```bash
sudo -u solvit psql -h localhost -d solvit_ticketing -U solvit_user
```

### Firewall issues
Check firewall status:
```bash
sudo ufw status
```

## Maintenance Commands

### Restart services
```bash
sudo systemctl restart solvit-ticketing
sudo systemctl restart nginx
```

### Update application
```bash
cd /opt/solvit-ticketing
sudo git pull  # If using git
sudo source venv/bin/activate
sudo pip install -r requirements.txt
sudo python manage.py migrate
sudo python manage.py collectstatic --noinput
sudo systemctl restart solvit-ticketing
```

### Backup database
```bash
sudo -u postgres pg_dump solvit_ticketing > solvit_backup_$(date +%Y%m%d).sql
```
