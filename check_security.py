#!/usr/bin/env python
"""
Security Validation Script for Django Ticketing System
Run this script before deploying to production to check for security issues.
"""

import os
import sys
import django
from pathlib import Path

# Add the project directory to the Python path
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

# Set the Django settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'it_ticketing_system.settings_production')

# Setup Django
django.setup()

from django.conf import settings
from django.core.management import call_command
from django.core.management.base import CommandError

class SecurityChecker:
    """Security validation checker for Django application"""
    
    def __init__(self):
        self.issues = []
        self.warnings = []
        
    def check_secret_key(self):
        """Check if SECRET_KEY is properly configured"""
        if not hasattr(settings, 'SECRET_KEY'):
            self.issues.append("❌ SECRET_KEY not configured")
            return
            
        secret_key = settings.SECRET_KEY
        if 'django-insecure' in secret_key:
            self.issues.append("❌ Using default insecure SECRET_KEY")
        elif len(secret_key) < 50:
            self.warnings.append("⚠️  SECRET_KEY should be at least 50 characters long")
        else:
            print("✅ SECRET_KEY properly configured")
    
    def check_debug_mode(self):
        """Check if DEBUG is disabled"""
        if settings.DEBUG:
            self.issues.append("❌ DEBUG mode is enabled (must be False in production)")
        else:
            print("✅ DEBUG mode disabled")
    
    def check_allowed_hosts(self):
        """Check ALLOWED_HOSTS configuration"""
        if not settings.ALLOWED_HOSTS:
            self.issues.append("❌ ALLOWED_HOSTS is empty")
        elif settings.ALLOWED_HOSTS == ['*']:
            self.issues.append("❌ ALLOWED_HOSTS allows all hosts (security risk)")
        else:
            print(f"✅ ALLOWED_HOSTS configured: {settings.ALLOWED_HOSTS}")
    
    def check_database_config(self):
        """Check database configuration security"""
        db_config = settings.DATABASES['default']
        
        if 'PASSWORD' in str(db_config) and 'password' in str(db_config['PASSWORD']).lower():
            self.warnings.append("⚠️  Database password might be too simple")
        
        if db_config.get('HOST') in ['localhost', '127.0.0.1']:
            print("✅ Database host configured for local/secure access")
        else:
            self.warnings.append("⚠️  Database host is external - ensure proper firewall rules")
    
    def check_security_middleware(self):
        """Check security middleware configuration"""
        required_middleware = [
            'django.middleware.security.SecurityMiddleware',
            'django.middleware.csrf.CsrfViewMiddleware',
            'django.middleware.clickjacking.XFrameOptionsMiddleware',
        ]
        
        missing_middleware = []
        for middleware in required_middleware:
            if middleware not in settings.MIDDLEWARE:
                missing_middleware.append(middleware)
        
        if missing_middleware:
            self.issues.append(f"❌ Missing security middleware: {missing_middleware}")
        else:
            print("✅ Security middleware properly configured")
    
    def check_https_settings(self):
        """Check HTTPS/SSL settings"""
        https_settings = [
            'SECURE_SSL_REDIRECT',
            'SECURE_HSTS_SECONDS',
            'SESSION_COOKIE_SECURE',
            'CSRF_COOKIE_SECURE'
        ]
        
        missing_settings = []
        for setting in https_settings:
            if not getattr(settings, setting, False):
                missing_settings.append(setting)
        
        if missing_settings:
            self.warnings.append(f"⚠️  HTTPS settings not fully configured: {missing_settings}")
        else:
            print("✅ HTTPS settings properly configured")
    
    def check_file_upload_settings(self):
        """Check file upload security settings"""
        max_size = getattr(settings, 'MAX_UPLOAD_SIZE', None)
        if not max_size:
            self.warnings.append("⚠️  MAX_UPLOAD_SIZE not configured")
        elif max_size > 10 * 1024 * 1024:  # 10MB
            self.warnings.append("⚠️  MAX_UPLOAD_SIZE is quite large (>10MB)")
        else:
            print(f"✅ File upload size limit: {max_size / (1024*1024):.1f}MB")
    
    def check_admin_url(self):
        """Check if admin URL is customized"""
        admin_url = getattr(settings, 'ADMIN_URL', 'admin/')
        if admin_url == 'admin/':
            self.warnings.append("⚠️  Admin URL is default (/admin/) - consider changing for security")
        else:
            print(f"✅ Custom admin URL configured: /{admin_url}")
    
    def check_logging_config(self):
        """Check logging configuration"""
        if not hasattr(settings, 'LOGGING'):
            self.warnings.append("⚠️  Logging not configured")
        else:
            print("✅ Logging configuration found")
    
    def check_environment_file(self):
        """Check if .env file exists and has proper permissions"""
        env_file = BASE_DIR / '.env'
        if not env_file.exists():
            self.issues.append("❌ .env file not found - copy from .env.example")
        else:
            # Check file permissions (should not be world-readable)
            permissions = oct(env_file.stat().st_mode)[-3:]
            if permissions.endswith('4') or permissions.endswith('6'):
                self.warnings.append("⚠️  .env file is world-readable - fix permissions with 'chmod 600 .env'")
            else:
                print("✅ .env file found with proper permissions")
    
    def run_django_security_check(self):
        """Run Django's built-in security check"""
        try:
            print("\n🔍 Running Django security check...")
            call_command('check', '--deploy', verbosity=0)
            print("✅ Django security check passed")
        except CommandError as e:
            self.issues.append(f"❌ Django security check failed: {e}")
    
    def check_dependencies(self):
        """Check for security-related dependencies"""
        required_packages = [
            'django-environ',
            'whitenoise',
            'gunicorn'
        ]
        
        try:
            import pkg_resources
            installed_packages = [pkg.project_name.lower() for pkg in pkg_resources.working_set]
            
            missing_packages = []
            for package in required_packages:
                if package.lower() not in installed_packages:
                    missing_packages.append(package)
            
            if missing_packages:
                self.warnings.append(f"⚠️  Recommended security packages missing: {missing_packages}")
            else:
                print("✅ Security-related packages installed")
        except ImportError:
            self.warnings.append("⚠️  Could not check package dependencies")
    
    def run_all_checks(self):
        """Run all security checks"""
        print("🔐 Starting Security Validation for Django Ticketing System")
        print("=" * 60)
        
        self.check_environment_file()
        self.check_secret_key()
        self.check_debug_mode()
        self.check_allowed_hosts()
        self.check_database_config()
        self.check_security_middleware()
        self.check_https_settings()
        self.check_file_upload_settings()
        self.check_admin_url()
        self.check_logging_config()
        self.check_dependencies()
        self.run_django_security_check()
        
        # Print summary
        print("\n" + "=" * 60)
        print("🔐 SECURITY VALIDATION SUMMARY")
        print("=" * 60)
        
        if not self.issues and not self.warnings:
            print("🎉 All security checks passed! Ready for production deployment.")
        else:
            if self.issues:
                print(f"\n❌ CRITICAL ISSUES ({len(self.issues)}):")
                for issue in self.issues:
                    print(f"  {issue}")
                print("\n🚨 Fix these issues before deploying to production!")
            
            if self.warnings:
                print(f"\n⚠️  WARNINGS ({len(self.warnings)}):")
                for warning in self.warnings:
                    print(f"  {warning}")
                print("\n💡 Consider addressing these warnings for better security.")
        
        print("\n📋 Next steps:")
        print("1. Review the DEPLOYMENT_SECURITY_CHECKLIST.md file")
        print("2. Configure your web server (Nginx/Apache)")
        print("3. Set up SSL/TLS certificates")
        print("4. Configure monitoring and logging")
        print("5. Test your deployment thoroughly")
        
        return len(self.issues) == 0

if __name__ == "__main__":
    checker = SecurityChecker()
    success = checker.run_all_checks()
    
    if not success:
        sys.exit(1)  # Exit with error code if there are critical issues
    else:
        sys.exit(0)  # Exit successfully
