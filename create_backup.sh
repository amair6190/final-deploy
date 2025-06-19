#!/bin/bash

# Backup script for SolvIT Ticketing System configuration
# This creates a backup of key configuration files before setting up with Nginx Proxy Manager

# Set colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Creating backup of current SolvIT Ticketing System configuration...${NC}"

# Create backup directory with timestamp
BACKUP_DIR="/home/amair/Desktop/deploy-ticket/solvit_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup critical files
echo -e "${YELLOW}Backing up .env file...${NC}"
cp -v /home/amair/Desktop/deploy-ticket/solvit-ticketing-system-v2/.env "$BACKUP_DIR/"

echo -e "${YELLOW}Backing up settings files...${NC}"
cp -v /home/amair/Desktop/deploy-ticket/solvit-ticketing-system-v2/it_ticketing_system/settings*.py "$BACKUP_DIR/"

echo -e "${YELLOW}Backing up Nginx configurations...${NC}"
mkdir -p "$BACKUP_DIR/nginx"
sudo cp -v /etc/nginx/sites-available/* "$BACKUP_DIR/nginx/"

echo -e "${YELLOW}Backing up systemd service...${NC}"
mkdir -p "$BACKUP_DIR/systemd"
sudo cp -v /etc/systemd/system/solvit-ticketing.service "$BACKUP_DIR/systemd/"

# Create a summary of current configuration
echo -e "${YELLOW}Collecting system information...${NC}"
echo "Backup created on $(date)" > "$BACKUP_DIR/backup_info.txt"
echo "Server IP: $(hostname -I | awk '{print $1}')" >> "$BACKUP_DIR/backup_info.txt"
echo "Python version: $(python3 --version)" >> "$BACKUP_DIR/backup_info.txt"
echo "Nginx version: $(nginx -v 2>&1)" >> "$BACKUP_DIR/backup_info.txt"
echo "Firewall status:" >> "$BACKUP_DIR/backup_info.txt"
sudo ufw status >> "$BACKUP_DIR/backup_info.txt"

echo -e "${GREEN}Backup completed successfully at: ${NC}"
echo "$BACKUP_DIR"
echo ""
echo -e "${YELLOW}You can restore your configuration from this backup if needed.${NC}"
