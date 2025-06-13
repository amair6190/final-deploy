# Production Deployment Security Checklist for Django Ticketing System

## 🚨 CRITICAL SECURITY FIXES REQUIRED

### 1. Environment Configuration
- [ ] Copy `.env.example` to `.env` and fill in all values
- [ ] Generate a new SECRET_KEY (50+ characters)
- [ ] Set DEBUG=False
- [ ] Configure ALLOWED_HOSTS with your domain
- [ ] Use environment variables for all sensitive data

### 2. Database Security
- [ ] Change database password from default
- [ ] Use a dedicated database user with minimal privileges
- [ ] Enable SSL/TLS for database connections
- [ ] Configure database firewall rules
- [ ] Regular database backups with encryption

### 3. Web Server Configuration
- [ ] Use HTTPS/SSL certificate (Let's Encrypt recommended)
- [ ] Configure proper security headers
- [ ] Hide server version information
- [ ] Set up fail2ban for intrusion prevention
- [ ] Configure rate limiting

### 4. File System Security
- [ ] Set proper file permissions (644 for files, 755 for directories)
- [ ] Separate media files from code
- [ ] Configure file upload restrictions
- [ ] Use a CDN for static files in production

### 5. Application Security
- [ ] Change default admin URL from /admin/
- [ ] Implement IP whitelisting for admin access
- [ ] Set up proper logging and monitoring
- [ ] Configure CSRF and session security
- [ ] Implement rate limiting for APIs

### 6. Infrastructure Security
- [ ] Update all system packages
- [ ] Configure firewall (UFW/iptables)
- [ ] Disable unused services
- [ ] Set up monitoring and alerting
- [ ] Configure automated security updates

## 🔧 QUICK SETUP COMMANDS

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Environment Setup
```bash
cp .env.example .env
# Edit .env file with your actual values
```

### 3. Database Migration
```bash
python manage.py makemigrations
python manage.py migrate
```

### 4. Create Superuser
```bash
python manage.py createsuperuser
```

### 5. Collect Static Files
```bash
python manage.py collectstatic --noinput
```

### 6. Test Production Settings
```bash
python manage.py check --deploy
```

## 🌐 NGINX CONFIGURATION EXAMPLE

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com www.your-domain.com;

    # SSL Configuration
    ssl_certificate /path/to/your/certificate.crt;
    ssl_certificate_key /path/to/your/private.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # File Upload Limits
    client_max_body_size 10M;

    # Static Files
    location /static/ {
        alias /path/to/your/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, no-transform";
    }

    # Media Files
    location /media/ {
        alias /path/to/your/media/;
        expires 1y;
        add_header Cache-Control "public, no-transform";
    }

    # Application
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 🐳 DOCKER PRODUCTION SETUP

### Dockerfile.prod
```dockerfile
FROM python:3.12-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy project
COPY . .

# Create non-root user
RUN adduser --disabled-password --gecos '' appuser
RUN chown -R appuser:appuser /app
USER appuser

# Collect static files
RUN python manage.py collectstatic --noinput

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "it_ticketing_system.wsgi:application"]
```

## 🔐 SECURITY MONITORING

### Log Files to Monitor
- `/path/to/logs/django.log` - Application logs
- `/path/to/logs/security.log` - Security events
- `/var/log/nginx/access.log` - Web server access
- `/var/log/nginx/error.log` - Web server errors

### Alerts to Set Up
- Failed login attempts (>5 per hour)
- File upload failures
- Database connection errors
- SSL certificate expiration
- Disk space usage (>80%)

## 🚀 PERFORMANCE OPTIMIZATION

### Redis Cache Setup
```bash
sudo apt-get install redis-server
sudo systemctl enable redis-server
sudo systemctl start redis-server
```

### Database Optimization
- Enable connection pooling
- Set up read replicas for high traffic
- Regular VACUUM and ANALYZE
- Monitor slow queries

## 📱 POST-DEPLOYMENT TESTING

### Security Tests
- [ ] SQL Injection testing
- [ ] XSS vulnerability scanning
- [ ] CSRF protection verification
- [ ] File upload security testing
- [ ] Authentication bypass attempts

### Performance Tests
- [ ] Load testing with Apache Bench
- [ ] Database query optimization
- [ ] Static file serving
- [ ] Memory usage monitoring

## 🔄 MAINTENANCE SCHEDULE

### Daily
- Monitor error logs
- Check system resources
- Verify backup completion

### Weekly
- Update system packages
- Review security logs
- Performance monitoring

### Monthly
- Security vulnerability scan
- Database maintenance
- SSL certificate check
- Backup restoration test

## 📞 INCIDENT RESPONSE PLAN

### Security Breach Response
1. Isolate affected systems
2. Change all passwords and API keys
3. Review access logs
4. Notify affected users
5. Document and report incident

### System Failure Response
1. Check system status
2. Restore from backup if needed
3. Verify data integrity
4. Communicate with users
5. Post-mortem analysis
