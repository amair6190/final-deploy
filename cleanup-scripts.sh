#!/bin/bash

# Clean up unwanted deployment scripts
# Keep only essential files for Ubuntu server deployment

echo "🧹 Cleaning up unwanted deployment scripts..."

# Remove Docker-related files
rm -f Dockerfile
rm -f Dockerfile.prod
rm -f docker-compose.yml
rm -f docker-compose.prod.yml

# Remove old deployment scripts
rm -f complete-deployment-fix-corrected.sh
rm -f complete-deployment-fix.sh
rm -f deploy_production.sh
rm -f deploy_with_your_db_config.sh
rm -f fix-deployment-script.sh
rm -f fix_django_installation.sh
rm -f simple_deploy.sh
rm -f check_status.sh

# Remove old settings files
rm -f settings_production_simple.py
rm -f settings_production_with_your_db.py

# Remove documentation files that are no longer needed
rm -f DEPLOYMENT_SECURITY_CHECKLIST.md
rm -f MANUAL_DEPLOYMENT_GUIDE.md
rm -f QUICK_DEPLOYMENT_COMMANDS.md
rm -f SOLVIT_DEPLOYMENT_GUIDE.md
rm -f SYSTEM_STATUS_REPORT.md
rm -f UBUNTU_DEPLOYMENT_READY.md
rm -f PRODUCTION_READY_STATUS.md

# Remove feature documentation (keep in git history if needed)
rm -f DROPBOX_STYLE_FILE_UPLOAD.md
rm -f FILE_UPLOAD_IMPLEMENTATION_COMPLETE.md
rm -f INTERACTIVE_FILE_UPLOAD_ENHANCED.md

# Remove old backup files
rm -f db_backup_20250612.sql
rm -f test_upload.txt

# Remove ubuntu-deployment directory (old approach)
rm -rf ubuntu-deployment/

# Remove nginx directory as we create config in the main script
rm -rf nginx/

# Remove check_security.py (functionality moved to main script)
rm -f check_security.py

# Remove venv directory (will be created by deployment script)
rm -rf venv/

# Remove staticfiles directory (will be created by deployment script)
rm -rf staticfiles/

echo "✅ Cleanup complete!"
echo ""
echo "📋 Remaining files:"
echo "Essential files kept:"
echo "  - deploy-ubuntu-server.sh      # Main deployment script"
echo "  - manage.py                    # Django management"
echo "  - requirements.txt             # Python dependencies"
echo "  - requirements_core.txt        # Core dependencies"
echo "  - .env.example                 # Environment example"
echo "  - README.md                    # Project documentation"
echo "  - Python Ticketing System Design.txt  # System design"
echo ""
echo "Application directories:"
echo "  - it_ticketing_system/         # Django project"
echo "  - tickets/                     # Main Django app"
echo "  - templates/                   # HTML templates"
echo "  - static/                      # Static files"
echo "  - media/                       # Media uploads"
echo ""
echo "🎯 Your project is now clean and ready for deployment!"
echo "Run: sudo ./deploy-ubuntu-server.sh"
