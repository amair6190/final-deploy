# SolvIT Ticketing System - Uninstall Guide

## 🗑️ Complete System Removal

This guide provides instructions for completely removing the SolvIT Django Ticketing System from your server.

## ⚠️ Important Warning

**The uninstallation process is IRREVERSIBLE!** 

The following will be permanently deleted:
- All application files and code
- Database and all ticket data
- User accounts and configurations
- Static files and media uploads
- System service configurations

**Please ensure you have backups of any important data before proceeding!**

## 📋 Pre-Uninstall Checklist

Before running the uninstall script, consider backing up:

### 1. Database Backup (Recommended)
```bash
# Backup the database
sudo -u postgres pg_dump test2 > solvit_ticketing_backup_$(date +%Y%m%d_%H%M%S).sql

# Or backup with gzip compression
sudo -u postgres pg_dump test2 | gzip > solvit_ticketing_backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

### 2. Media Files Backup (if you have uploads)
```bash
# Backup media files (attachments, uploads, etc.)
sudo cp -r /opt/solvit-ticketing/media ~/solvit_media_backup_$(date +%Y%m%d_%H%M%S)
```

### 3. Configuration Files Backup
```bash
# Backup custom configurations
sudo cp /opt/solvit-ticketing/it_ticketing_system/settings_production.py ~/settings_backup.py
sudo cp /opt/solvit-ticketing/it_ticketing_system/jazzmin_settings.py ~/jazzmin_backup.py
```

## 🚀 Running the Uninstall Script

### Method 1: Interactive Uninstall (Recommended)
```bash
# Make the script executable (if not already done)
chmod +x uninstall-solvit-ticketing.sh

# Run the interactive uninstall script
./uninstall-solvit-ticketing.sh
```

### Method 2: Quick Uninstall (Advanced Users)
```bash
# For experienced users who want to skip confirmations
# Note: This is still interactive for safety
sudo ./uninstall-solvit-ticketing.sh
```

## 📝 What the Script Does

The uninstall script performs the following actions in order:

### 1. Service Management
- Stops the `solvit-ticketing` systemd service
- Disables the service from auto-start
- Removes the service file from `/etc/systemd/system/`
- Reloads systemd daemon

### 2. Web Server Configuration
- Checks for and removes Nginx configuration files
- Reloads Nginx if configurations were removed

### 3. Database Cleanup
- Drops the PostgreSQL database (`test2`)
- Removes the database user (`test2`)
- Optionally removes PostgreSQL entirely (if installed only for this app)

### 4. Application Files
- Removes all files from `/opt/solvit-ticketing/`
- Includes Python virtual environment, static files, media files
- Cleans up file permissions

### 5. Process Cleanup
- Identifies and terminates any remaining related processes
- Ensures clean system state

### 6. Optional System Cleanup
- Removes Python packages that were installed for the project
- Cleans package cache
- Removes temporary files

## 🔧 Manual Cleanup (If Script Fails)

If the automated script encounters issues, you can manually remove components:

### Stop Services
```bash
sudo systemctl stop solvit-ticketing
sudo systemctl disable solvit-ticketing
sudo rm /etc/systemd/system/solvit-ticketing.service
sudo systemctl daemon-reload
```

### Remove Database
```bash
sudo -u postgres psql -c "DROP DATABASE IF EXISTS test2;"
sudo -u postgres psql -c "DROP USER IF EXISTS test2;"
```

### Remove Application Files
```bash
sudo rm -rf /opt/solvit-ticketing
```

### Remove Nginx Configuration (if exists)
```bash
sudo rm -f /etc/nginx/sites-available/solvit-ticketing
sudo rm -f /etc/nginx/sites-enabled/solvit-ticketing
sudo nginx -t && sudo systemctl reload nginx
```

## 🔍 Verification After Uninstall

After running the uninstall script, verify complete removal:

### Check Services
```bash
# Should return no results
systemctl list-units --type=service | grep solvit

# Check if service file exists (should not exist)
ls -la /etc/systemd/system/ | grep solvit
```

### Check Files
```bash
# Should return "No such file or directory"
ls -la /opt/solvit-ticketing

# Check for any remaining processes
ps aux | grep solvit
```

### Check Database
```bash
# Should not list test2 database
sudo -u postgres psql -l | grep test2

# Should not list test2 user
sudo -u postgres psql -c "\\du" | grep test2
```

### Check Nginx
```bash
# Should not show solvit-ticketing
sudo nginx -T | grep solvit
```

## 🚨 Troubleshooting

### Common Issues and Solutions

#### Permission Denied Errors
```bash
# Fix ownership issues
sudo chown -R $(whoami):$(whoami) /opt/solvit-ticketing
# Then try removing again
sudo rm -rf /opt/solvit-ticketing
```

#### Database Connection Errors
```bash
# If PostgreSQL service is not running
sudo systemctl start postgresql
# Then try database removal again
```

#### Service Still Running
```bash
# Force kill any remaining processes
sudo pkill -f "solvit-ticketing"
sudo pkill -f "gunicorn.*it_ticketing_system"
```

#### Nginx Configuration Issues
```bash
# Test nginx configuration
sudo nginx -t
# If there are errors, manually edit the config files
```

## 📞 Support

If you encounter issues during uninstallation:

1. **Check the script output** - It provides detailed information about each step
2. **Review system logs** - `sudo journalctl -xe` for recent system events
3. **Manual cleanup** - Use the manual steps provided above
4. **Backup first** - Always backup important data before troubleshooting

## ⚡ Quick Reference Commands

```bash
# Full backup before uninstall
sudo -u postgres pg_dump test2 > backup.sql
sudo cp -r /opt/solvit-ticketing/media ~/media_backup

# Run uninstall
./uninstall-solvit-ticketing.sh

# Verify removal
systemctl list-units --type=service | grep solvit
ls -la /opt/solvit-ticketing
sudo -u postgres psql -l | grep test2
```

---

## 🔄 Reinstallation

If you need to reinstall the system after uninstalling:

1. Use the original `deploy-ubuntu-server.sh` script
2. Restore database from backup if needed:
   ```bash
   sudo -u postgres createdb test2
   sudo -u postgres psql test2 < backup.sql
   ```
3. Restore media files:
   ```bash
   sudo cp -r ~/media_backup /opt/solvit-ticketing/media
   ```

---

**Remember**: Always backup your data before uninstalling any system!
