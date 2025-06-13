# 🚀 Quick Start - Django Ticketing System Deployment

## Step 1: Prepare Your Server
```bash
# Update your Ubuntu server
sudo apt update && sudo apt upgrade -y

# Install git if not already installed
sudo apt install git -y
```

## Step 2: Upload Deployment Scripts
```bash
# Option A: Upload via SCP
scp -r ubuntu-deployment/ user@your-server:/tmp/

# Option B: Clone from repository
git clone https://github.com/amair6190/solvit-django-ticketing-system.git
cd solvit-django-ticketing-system/ubuntu-deployment
```

## Step 3: Run Deployment
```bash
# SSH to your server
ssh user@your-server

# Navigate to deployment directory
cd /tmp/ubuntu-deployment

# Make scripts executable
chmod +x *.sh

# Run master deployment script
sudo ./deploy.sh
```

## Step 4: Follow Prompts
The script will ask for:
- **Domain name**: `example.com`
- **Email address**: `admin@example.com`
- **Admin email**: `alerts@example.com`

## Step 5: Wait for Completion
- ⏱️ **Estimated time**: 10-15 minutes
- 📊 **Progress**: Watch for phase completion messages
- ✅ **Success**: "Deployment Complete!" message

## Step 6: Test Your Application
```bash
# Check services
/opt/django-ticketing/health_check.sh

# Test web access
curl -I https://your-domain.com

# View logs if needed
tail -f /opt/django-ticketing/logs/gunicorn_error.log
```

## 🎉 That's It!
Your Django Ticketing System is now live at:
- **Application**: `https://your-domain.com`
- **Admin Panel**: `https://your-domain.com/admin/`

## 📋 Next Steps
1. Login to admin panel with superuser account
2. Configure email settings in Django admin
3. Test file upload functionality
4. Review security settings
5. Set up monitoring alerts

## ⚠️ Important Notes
- Replace `your-domain.com` with your actual domain
- Ensure DNS points to your server IP
- SSL certificates are automatically installed
- All services start automatically on boot

**Need help?** Check the full README.md for detailed documentation.
