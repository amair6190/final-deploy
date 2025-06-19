#!/bin/bash

# SolvIT Ticketing System - Gunicorn Binding Fix Script
# This script fixes the Gunicorn binding configuration to listen on all interfaces
# instead of just localhost to prevent the ERR_CONNECTION_REFUSED error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    SolvIT Ticketing System - Gunicorn Binding Fix ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Service file path
SERVICE_FILE="/etc/systemd/system/solvit-ticketing.service"

# Check if service file exists
if [ ! -f "$SERVICE_FILE" ]; then
    echo -e "${RED}Service file not found: $SERVICE_FILE${NC}"
    echo -e "${YELLOW}Are you running this on the server with SolvIT Ticketing System installed?${NC}"
    exit 1
fi

# Check if the binding is already set to 0.0.0.0
if grep -q "bind 0.0.0.0:8001" "$SERVICE_FILE"; then
    echo -e "${GREEN}✓ Gunicorn is already configured to listen on all interfaces (0.0.0.0).${NC}"
else
    echo -e "${YELLOW}Gunicorn is currently configured to listen only on localhost (127.0.0.1).${NC}"
    echo -e "${YELLOW}Updating configuration to listen on all interfaces...${NC}"
    
    # Make the change
    sed -i 's/--bind 127.0.0.1:8001/--bind 0.0.0.0:8001/g' "$SERVICE_FILE"
    
    # Verify the change was made
    if grep -q "bind 0.0.0.0:8001" "$SERVICE_FILE"; then
        echo -e "${GREEN}✓ Configuration updated successfully!${NC}"
        
        # Reload systemd and restart the service
        echo -e "${YELLOW}Reloading systemd daemon and restarting the service...${NC}"
        systemctl daemon-reload
        systemctl restart solvit-ticketing
        
        # Check service status
        echo -e "${YELLOW}Checking service status...${NC}"
        systemctl status solvit-ticketing --no-pager
        
        # Test connection
        echo -e "${YELLOW}Testing connection to localhost...${NC}"
        curl -Is http://127.0.0.1:8001 > /dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Connection to localhost successful.${NC}"
        else
            echo -e "${RED}✗ Connection to localhost failed.${NC}"
        fi
        
        # Get server IP
        SERVER_IP=$(hostname -I | awk '{print $1}')
        echo -e "${YELLOW}Testing connection to server IP ($SERVER_IP)...${NC}"
        curl -Is http://$SERVER_IP:8001 > /dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Connection to server IP successful.${NC}"
        else
            echo -e "${RED}✗ Connection to server IP failed.${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to update configuration.${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Done! Your SolvIT Ticketing System should now be accessible from other machines.${NC}"
echo -e "${BLUE}Remember to update your Nginx Proxy Manager or other reverse proxy configurations if needed.${NC}"
echo ""
