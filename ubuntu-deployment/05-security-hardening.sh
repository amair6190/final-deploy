#!/bin/bash

# Django Ticketing System - Security Hardening Script
# Phase 5: Final security configuration and hardening
# Run this script as root after Nginx setup

set -e  # Exit on any error

echo "🔒 Django Ticketing System - Security Hardening"
echo "=============================================="
echo "Phase 5: Final security configuration and system hardening"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[CONFIG]${NC} $1"
}

# Configuration variables
SERVER_IP=$(curl -s ifconfig.me || echo "unknown")

print_status "Security Hardening Configuration:"
print_info "Server IP: $SERVER_IP"

# Configure UFW Firewall
print_status "Configuring UFW firewall..."

# Reset UFW to defaults
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (adjust port if you've changed it)
ufw allow OpenSSH

# Allow HTTP and HTTPS
ufw allow 'Nginx Full'

# Allow PostgreSQL only from localhost
ufw allow from 127.0.0.1 to any port 5432

# Allow Redis only from localhost
ufw allow from 127.0.0.1 to any port 6379

# Enable UFW
ufw --force enable

print_status "Firewall rules configured"

# Configure fail2ban for additional security
print_status "Installing and configuring fail2ban..."
apt install -y fail2ban

# Create fail2ban configuration for Django
cat > /etc/fail2ban/jail.d/django-ticketing.conf << 'EOF'
[DEFAULT]
# Default ban time: 10 minutes
bantime = 600
# Find time window: 10 minutes
findtime = 600
# Max retries before ban
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10

[django-auth]
enabled = true
filter = django-auth
port = http,https
logpath = /opt/django-ticketing/logs/django.log
maxretry = 5
bantime = 1800
EOF

# Create custom fail2ban filter for Django authentication
cat > /etc/fail2ban/filter.d/django-auth.conf << 'EOF'
[Definition]
failregex = ^.* Invalid login attempt.* <HOST>.*$
            ^.* Failed login for .* from <HOST>.*$
            ^.* Authentication failed for .* from <HOST>.*$

ignoreregex =
EOF

# Start and enable fail2ban
systemctl enable fail2ban
systemctl restart fail2ban

# Configure automatic security updates
print_status "Configuring automatic security updates..."
apt install -y unattended-upgrades apt-listchanges

# Configure unattended upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";

Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailReport "on-change";
EOF

# Secure shared memory
print_status "Securing shared memory..."
if ! grep -q "tmpfs /run/shm" /etc/fstab; then
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
fi

# Configure kernel security parameters
print_status "Configuring kernel security parameters..."
cat > /etc/sysctl.d/99-django-ticketing-security.conf << 'EOF'
# Django Ticketing System Security Configuration

# IP Spoofing protection
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_all = 1

# Ignore Directed pings
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# TCP SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Control buffer overflow attacks
kernel.exec-shield = 1
kernel.randomize_va_space = 2

# Hide kernel pointers
kernel.kptr_restrict = 1

# Restrict dmesg
kernel.dmesg_restrict = 1
EOF

# Apply sysctl settings
sysctl -p /etc/sysctl.d/99-django-ticketing-security.conf

# Configure SSH security (if SSH is being used)
print_status "Hardening SSH configuration..."
if [ -f /etc/ssh/sshd_config ]; then
    # Backup original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Apply SSH hardening
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config
    sed -i 's/X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
    
    # Add additional security settings
    cat >> /etc/ssh/sshd_config << 'EOF'

# Django Ticketing System SSH Security
Protocol 2
MaxAuthTries 3
MaxStartups 10:30:60
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers django-user
DenyUsers root
EOF
    
    # Restart SSH service
    systemctl restart sshd
fi

# Install and configure ClamAV antivirus
print_status "Installing and configuring ClamAV antivirus..."
apt install -y clamav clamav-daemon

# Update virus definitions
print_status "Updating virus definitions..."
systemctl stop clamav-freshclam
freshclam
systemctl start clamav-freshclam
systemctl enable clamav-freshclam

# Create virus scan script
cat > /opt/django-ticketing/virus_scan.sh << 'EOF'
#!/bin/bash
# Virus scan script for Django Ticketing System

SCAN_DIR="/opt/django-ticketing/app/media"
LOG_FILE="/opt/django-ticketing/logs/virus_scan.log"

echo "🦠 Starting virus scan at $(date)" >> "$LOG_FILE"

# Scan media directory
clamscan -r --bell -i "$SCAN_DIR" >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Virus scan completed - No threats found" >> "$LOG_FILE"
else
    echo "⚠️ Virus scan completed - Please check log for details" >> "$LOG_FILE"
    # Send alert email (uncomment and configure mail)
    # echo "Virus scan found issues on $(hostname)" | mail -s "Virus Scan Alert" admin@your-domain.com
fi

echo "📅 Scan completed at $(date)" >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"
EOF

chmod +x /opt/django-ticketing/virus_scan.sh
chown django-user:django-user /opt/django-ticketing/virus_scan.sh

# Add virus scan to crontab (weekly)
cat > /etc/cron.d/django-ticketing-virus-scan << 'EOF'
# Weekly virus scan for Django Ticketing System
0 3 * * 0 django-user /opt/django-ticketing/virus_scan.sh
EOF

# Configure log monitoring with logwatch
print_status "Installing and configuring log monitoring..."
apt install -y logwatch

# Create custom logwatch configuration
mkdir -p /etc/logwatch/conf/services
cat > /etc/logwatch/conf/services/django-ticketing.conf << 'EOF'
Title = "Django Ticketing System"
LogFile = django-ticketing
*OnlyService = django-ticketing
*RemoveHeaders
EOF

# Configure logwatch to send daily reports
cat > /etc/cron.d/django-ticketing-logwatch << 'EOF'
# Daily log analysis for Django Ticketing System
0 6 * * * root /usr/sbin/logwatch --output mail --mailto root --detail high --service django-ticketing --range yesterday
EOF

# Create security audit script
print_status "Creating security audit script..."
cat > /opt/django-ticketing/security_audit.sh << 'EOF'
#!/bin/bash
# Security audit script for Django Ticketing System

echo "🔒 Django Ticketing System Security Audit"
echo "========================================"
echo "Date: $(date)"
echo ""

# Check service status
echo "📋 Service Status:"
services=("nginx" "postgresql" "redis-server" "django-ticketing" "fail2ban")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo "  ✅ $service: Active"
    else
        echo "  ❌ $service: Inactive"
    fi
done
echo ""

# Check firewall status
echo "🔥 Firewall Status:"
ufw status numbered
echo ""

# Check fail2ban status
echo "🚫 Fail2ban Status:"
fail2ban-client status
echo ""

# Check open ports
echo "🔌 Open Ports:"
netstat -tuln | grep LISTEN
echo ""

# Check recent failed login attempts
echo "🔑 Recent Failed Logins:"
grep "Failed" /var/log/auth.log | tail -10
echo ""

# Check disk usage
echo "💾 Disk Usage:"
df -h | grep -E '^/dev/'
echo ""

# Check system updates
echo "📦 Available Updates:"
apt list --upgradable 2>/dev/null | wc -l
echo ""

# Check SSL certificate expiry
echo "🔒 SSL Certificate Status:"
if [ -f /etc/letsencrypt/live/*/cert.pem ]; then
    openssl x509 -in /etc/letsencrypt/live/*/cert.pem -noout -enddate
else
    echo "  ⚠️ Let's Encrypt certificate not found (using self-signed)"
fi
echo ""

# Check for suspicious files
echo "🔍 Security Scan:"
find /opt/django-ticketing/app/media -name "*.php" -o -name "*.exe" -o -name "*.sh" | head -5
echo ""

echo "✅ Security audit completed"
EOF

chmod +x /opt/django-ticketing/security_audit.sh

# Add security audit to crontab (weekly)
cat > /etc/cron.d/django-ticketing-security-audit << 'EOF'
# Weekly security audit for Django Ticketing System
0 4 * * 1 root /opt/django-ticketing/security_audit.sh >> /opt/django-ticketing/logs/security_audit.log 2>&1
EOF

# Set up intrusion detection with AIDE
print_status "Installing AIDE intrusion detection..."
apt install -y aide

# Initialize AIDE database
print_status "Initializing AIDE database (this may take a few minutes)..."
aideinit
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Create AIDE check script
cat > /opt/django-ticketing/aide_check.sh << 'EOF'
#!/bin/bash
# AIDE intrusion detection check

AIDE_LOG="/opt/django-ticketing/logs/aide.log"

echo "🛡️ Running AIDE integrity check at $(date)" >> "$AIDE_LOG"

aide --check >> "$AIDE_LOG" 2>&1

if [ $? -eq 0 ]; then
    echo "✅ No changes detected" >> "$AIDE_LOG"
else
    echo "⚠️ File system changes detected - Please review" >> "$AIDE_LOG"
    # Send alert email (uncomment and configure mail)
    # tail -50 "$AIDE_LOG" | mail -s "AIDE Alert - File System Changes" admin@your-domain.com
fi

echo "----------------------------------------" >> "$AIDE_LOG"
EOF

chmod +x /opt/django-ticketing/aide_check.sh

# Add AIDE check to crontab (daily)
cat > /etc/cron.d/django-ticketing-aide << 'EOF'
# Daily AIDE integrity check for Django Ticketing System
0 5 * * * root /opt/django-ticketing/aide_check.sh
EOF

# Set proper file permissions
print_status "Setting proper file permissions..."
chown -R django-user:django-user /opt/django-ticketing
chmod -R 755 /opt/django-ticketing
chmod 600 /opt/django-ticketing/.db_credentials
chmod 600 /opt/django-ticketing/app/.env
chmod 755 /opt/django-ticketing/*.sh

# Remove unnecessary packages
print_status "Removing unnecessary packages..."
apt autoremove -y
apt autoclean

# Update package database
print_status "Updating package database..."
apt update

print_status "✅ Phase 5 Complete: Security hardening configured"
print_status "📋 Security Summary:"
echo "   - UFW firewall configured and enabled"
echo "   - Fail2ban installed and configured"
echo "   - Automatic security updates enabled"
echo "   - Kernel security parameters optimized"
echo "   - SSH hardened (if applicable)"
echo "   - ClamAV antivirus installed"
echo "   - Log monitoring with logwatch"
echo "   - AIDE intrusion detection system"
echo "   - Security audit scripts created"
echo "   - File permissions secured"
echo ""
print_status "🔒 Security Scripts Created:"
echo "   - Virus scan: /opt/django-ticketing/virus_scan.sh"
echo "   - Security audit: /opt/django-ticketing/security_audit.sh" 
echo "   - AIDE check: /opt/django-ticketing/aide_check.sh"
echo ""
print_warning "⚠️ Manual Security Tasks:"
echo "   1. Configure SSH key authentication"
echo "   2. Set up email alerts (configure mail system)"
echo "   3. Review and customize firewall rules"
echo "   4. Set up external monitoring"
echo "   5. Regular security updates and patches"
