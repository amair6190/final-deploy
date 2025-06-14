# SolvIT Django Ticketing System - Project Scripts Summary

## 📋 Available Scripts

This project includes several utility scripts for deployment, testing, and maintenance:

### 🚀 Deployment Script
**File**: `deploy-ubuntu-server.sh`
**Purpose**: Complete automated deployment on Ubuntu servers

**Features**:
- Interactive configuration prompts
- Automatic dependency installation (Python, PostgreSQL, Nginx)
- Virtual environment setup
- Database creation and configuration
- Static files collection with Jazzmin theme support
- Systemd service configuration
- Security hardening
- Django superuser creation

**Usage**:
```bash
chmod +x deploy-ubuntu-server.sh
./deploy-ubuntu-server.sh
```

### 🗑️ Uninstall Script
**File**: `uninstall-solvit-ticketing.sh`
**Purpose**: Complete system removal with safety checks

**Features**:
- Interactive confirmation prompts
- Service shutdown and removal
- Database and user cleanup
- Application files removal
- Nginx configuration cleanup
- Process termination
- System cleanup and verification

**Usage**:
```bash
chmod +x uninstall-solvit-ticketing.sh
./uninstall-solvit-ticketing.sh
```

⚠️ **WARNING**: This script permanently removes all data!

### 🧪 Uninstall Test Script
**File**: `test-uninstall.sh`
**Purpose**: Test system components before uninstalling (non-destructive)

**Features**:
- Service status checking
- File system verification
- Database connectivity testing
- Process monitoring
- Package verification
- Disk usage analysis

**Usage**:
```bash
chmod +x test-uninstall.sh
./test-uninstall.sh
```

### 🧹 Cleanup Scripts
**File**: `cleanup-scripts.sh`
**Purpose**: Development environment cleanup

**Usage**:
```bash
chmod +x cleanup-scripts.sh
./cleanup-scripts.sh
```

## 📁 Project Structure

```
solvit-django-ticketing-system/
├── deploy-ubuntu-server.sh          # Main deployment script
├── uninstall-solvit-ticketing.sh    # System uninstall script
├── test-uninstall.sh               # Pre-uninstall testing
├── cleanup-scripts.sh              # Development cleanup
├── test-interactive-prompts.sh     # Interactive testing
├── README.md                       # Main project documentation
├── UNINSTALL_README.md             # Detailed uninstall guide
├── DEPLOYMENT_README.md            # Deployment documentation
├── requirements.txt                # Python dependencies
├── manage.py                       # Django management
├── db.sqlite3                      # Development database
├── it_ticketing_system/            # Django project settings
│   ├── settings.py                 # Development settings
│   ├── settings_production.py     # Production settings
│   ├── jazzmin_settings.py        # Admin theme configuration
│   └── ...
├── tickets/                        # Main Django app
│   ├── models.py                   # Database models
│   ├── views.py                    # Business logic
│   ├── forms.py                    # Form definitions
│   ├── admin.py                    # Admin interface
│   └── ...
├── templates/                      # HTML templates
├── static/                         # Static files (CSS, JS, images)
└── media/                          # User uploads
```

## 🔧 Script Permissions

After cloning the repository, make all scripts executable:

```bash
chmod +x *.sh
```

## 📖 Documentation Files

- **README.md**: Main project documentation with installation and usage
- **UNINSTALL_README.md**: Comprehensive uninstall guide with backup procedures
- **DEPLOYMENT_README.md**: Detailed deployment instructions and troubleshooting
- **DATABASE_NAMING_GUIDE.md**: Database naming conventions
- **STATIC_FILES_FIX.md**: Static files configuration guide

## 🛡️ Security Considerations

### Deployment Script
- Prompts for secure database passwords
- Creates non-root service user
- Implements proper file permissions
- Uses environment-specific settings

### Uninstall Script
- Multiple confirmation prompts
- Backup recommendations
- Safe process termination
- Non-destructive testing option

## 🧪 Testing Scripts

Before using the main scripts in production:

1. **Test the deployment on a VM or test server**
2. **Run the uninstall test script** to verify system state
3. **Create backups** before any destructive operations
4. **Review logs** for any issues

## 📞 Support and Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure scripts have execute permissions
2. **Service Conflicts**: Check for existing services on the same ports
3. **Database Errors**: Verify PostgreSQL installation and permissions
4. **Static Files**: Run test script to verify file locations

### Log Locations

- **System Service**: `sudo journalctl -u solvit-ticketing`
- **Nginx**: `/var/log/nginx/error.log`
- **PostgreSQL**: `/var/log/postgresql/`
- **Django**: Application logs in production settings

## 🔄 Maintenance

### Regular Tasks
- Database backups: `sudo -u postgres pg_dump test2 > backup.sql`
- Log rotation: Configured automatically with systemd
- Static files update: `python manage.py collectstatic`
- Security updates: `sudo apt update && sudo apt upgrade`

### Monitoring
- Service status: `systemctl status solvit-ticketing`
- Database connections: `sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"`
- Disk usage: `df -h` and `du -sh /opt/solvit-ticketing`

---

**Note**: Always test scripts in a development environment before using in production!
