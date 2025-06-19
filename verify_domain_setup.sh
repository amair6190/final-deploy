#!/bin/bash

# SolvIT Ticketing System - Domain Configuration Verification Script
# This script helps verify and fix domain configuration issues

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    SolvIT Ticketing System - Domain Verification ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"

# Get the domain name
DOMAIN="support.solvitservices.com"
read -p "Enter your domain name [default: $DOMAIN]: " USER_DOMAIN
if [ -n "$USER_DOMAIN" ]; then
    DOMAIN=$USER_DOMAIN
fi

# Get the server IP
SERVER_IP=$(hostname -I | awk '{print $1}')
read -p "Enter your server IP [default: $SERVER_IP]: " USER_IP
if [ -n "$USER_IP" ]; then
    SERVER_IP=$USER_IP
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${YELLOW}Note: Some tests may require root privileges for full functionality${NC}"
fi

echo -e "\n${BLUE}Step 1: Checking your current server IP${NC}"
echo -e "${YELLOW}Server hostname: $(hostname)${NC}"
echo -e "${YELLOW}Server IP address: $SERVER_IP${NC}"

echo -e "\n${BLUE}Step 2: Checking domain DNS resolution${NC}"
DNS_IP=$(nslookup $DOMAIN | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
echo -e "${YELLOW}Domain $DOMAIN resolves to: $DNS_IP${NC}"

if [[ "$DNS_IP" == "127.0.0.1" ]]; then
    echo -e "${RED}⚠️ Warning: Your domain is currently resolving to localhost (127.0.0.1)${NC}"
    echo -e "${RED}This will only work on the server itself, not from other devices${NC}"
    echo -e "${YELLOW}You should update your DNS settings to point to: $SERVER_IP${NC}"
    
    # Check if hosts file has an entry for this domain
    if grep -q "$DOMAIN" /etc/hosts; then
        echo -e "${YELLOW}Found entry in /etc/hosts file that may be causing this:${NC}"
        grep "$DOMAIN" /etc/hosts
        
        read -p "Would you like to update /etc/hosts to use your server IP? (y/n): " UPDATE_HOSTS
        if [[ "$UPDATE_HOSTS" == "y" || "$UPDATE_HOSTS" == "Y" ]]; then
            # Check if we have root permissions
            if [[ $EUID -ne 0 ]]; then
                echo -e "${RED}Error: Updating hosts file requires root privileges${NC}"
                echo -e "${YELLOW}Please run this script with sudo${NC}"
            else
                # Update hosts file
                sed -i "s/.*$DOMAIN.*/$SERVER_IP $DOMAIN www.$DOMAIN/" /etc/hosts
                echo -e "${GREEN}✓ Updated /etc/hosts file${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}No entry in /etc/hosts file for $DOMAIN${NC}"
        echo -e "${YELLOW}This is likely a DNS configuration issue with your domain registrar${NC}"
    fi
elif [[ "$DNS_IP" == "$SERVER_IP" ]]; then
    echo -e "${GREEN}✓ Domain is correctly pointing to your server IP${NC}"
else
    echo -e "${YELLOW}⚠️ Your domain is pointing to $DNS_IP, not your current server IP ($SERVER_IP)${NC}"
    echo -e "${YELLOW}This is expected if using a separate proxy server or load balancer${NC}"
    
    # Test if the domain IP responds
    echo -e "${YELLOW}Testing connectivity to $DNS_IP:80...${NC}"
    if curl -s --connect-timeout 5 -I "http://$DNS_IP:80" > /dev/null; then
        echo -e "${GREEN}✓ Successfully connected to $DNS_IP:80${NC}"
    else
        echo -e "${RED}✗ Failed to connect to $DNS_IP:80${NC}"
        echo -e "${YELLOW}If this is your proxy server, make sure it's running and accessible${NC}"
    fi
fi

echo -e "\n${BLUE}Step 3: Testing connectivity to your application${NC}"

# Test direct access to the application server
echo -e "${YELLOW}Testing connectivity to your application server ($SERVER_IP:8001)...${NC}"
if curl -s --connect-timeout 5 -I "http://$SERVER_IP:8001" > /dev/null; then
    echo -e "${GREEN}✓ Successfully connected to $SERVER_IP:8001${NC}"
else
    echo -e "${RED}✗ Failed to connect to $SERVER_IP:8001${NC}"
    echo -e "${YELLOW}This may indicate Gunicorn is not running or not listening on the correct interface${NC}"
    echo -e "${YELLOW}Run the following to check:${NC}"
    echo -e "${YELLOW}  sudo systemctl status solvit-ticketing${NC}"
    echo -e "${YELLOW}  sudo lsof -i :8001${NC}"
fi

# Test domain access
echo -e "${YELLOW}Testing connectivity to your domain ($DOMAIN)...${NC}"
if curl -s --connect-timeout 5 -I "http://$DOMAIN" > /dev/null; then
    echo -e "${GREEN}✓ Successfully connected to $DOMAIN${NC}"
else
    echo -e "${RED}✗ Failed to connect to $DOMAIN${NC}"
    echo -e "${YELLOW}This may indicate an issue with your proxy configuration or DNS${NC}"
fi

# Test domain access with HTTPS
echo -e "${YELLOW}Testing HTTPS access to your domain (https://$DOMAIN)...${NC}"
if curl -s --connect-timeout 5 -I -k "https://$DOMAIN" > /dev/null; then
    echo -e "${GREEN}✓ Successfully connected to https://$DOMAIN${NC}"
else
    echo -e "${RED}✗ Failed to connect to https://$DOMAIN${NC}"
    echo -e "${YELLOW}This may indicate SSL is not configured correctly${NC}"
fi

echo -e "\n${BLUE}Step 4: Checking CSRF configuration${NC}"

# Check if the domain is in CSRF_TRUSTED_ORIGINS
APP_DIR="/opt/solvit-ticketing"
ENV_FILE="$APP_DIR/.env"

if [ -f "$ENV_FILE" ] && [ -r "$ENV_FILE" ]; then
    if grep -q "CSRF_TRUSTED_ORIGINS" "$ENV_FILE"; then
        CSRF_CONFIG=$(grep "CSRF_TRUSTED_ORIGINS" "$ENV_FILE")
        echo -e "${YELLOW}Current CSRF configuration:${NC}"
        echo -e "${YELLOW}$CSRF_CONFIG${NC}"
        
        # Check if domain is in the config
        if ! grep -q "$DOMAIN" "$ENV_FILE"; then
            echo -e "${RED}⚠️ Your domain $DOMAIN is not in CSRF_TRUSTED_ORIGINS${NC}"
            echo -e "${YELLOW}This may cause CSRF verification errors when submitting forms${NC}"
            
            if [[ $EUID -eq 0 ]]; then
                read -p "Would you like to add $DOMAIN to CSRF_TRUSTED_ORIGINS? (y/n): " ADD_CSRF
                if [[ "$ADD_CSRF" == "y" || "$ADD_CSRF" == "Y" ]]; then
                    # Backup the .env file
                    cp "$ENV_FILE" "$ENV_FILE.bak.$(date +%Y%m%d%H%M%S)"
                    
                    # Add domain to CSRF_TRUSTED_ORIGINS
                    if grep -q "CSRF_TRUSTED_ORIGINS=" "$ENV_FILE"; then
                        sed -i "s|CSRF_TRUSTED_ORIGINS=|CSRF_TRUSTED_ORIGINS=https://$DOMAIN,http://$DOMAIN,|" "$ENV_FILE"
                        echo -e "${GREEN}✓ Added $DOMAIN to CSRF_TRUSTED_ORIGINS${NC}"
                    else
                        echo "CSRF_TRUSTED_ORIGINS=https://$DOMAIN,http://$DOMAIN" >> "$ENV_FILE"
                        echo -e "${GREEN}✓ Added CSRF_TRUSTED_ORIGINS with $DOMAIN to .env file${NC}"
                    fi
                fi
            else
                echo -e "${YELLOW}To update the CSRF configuration, run this script as root${NC}"
            fi
        else
            echo -e "${GREEN}✓ Your domain is included in CSRF_TRUSTED_ORIGINS${NC}"
        fi
    else
        echo -e "${YELLOW}CSRF_TRUSTED_ORIGINS not found in $ENV_FILE${NC}"
        echo -e "${YELLOW}This may cause CSRF verification errors when submitting forms${NC}"
        
        if [[ $EUID -eq 0 ]]; then
            read -p "Would you like to add CSRF_TRUSTED_ORIGINS to the .env file? (y/n): " ADD_CSRF
            if [[ "$ADD_CSRF" == "y" || "$ADD_CSRF" == "Y" ]]; then
                # Backup the .env file
                cp "$ENV_FILE" "$ENV_FILE.bak.$(date +%Y%m%d%H%M%S)"
                
                # Add CSRF_TRUSTED_ORIGINS
                echo "CSRF_TRUSTED_ORIGINS=https://$DOMAIN,http://$DOMAIN" >> "$ENV_FILE"
                echo -e "${GREEN}✓ Added CSRF_TRUSTED_ORIGINS with $DOMAIN to .env file${NC}"
            fi
        else
            echo -e "${YELLOW}To update the CSRF configuration, run this script as root${NC}"
        fi
    fi
else
    echo -e "${YELLOW}Could not read $ENV_FILE${NC}"
    echo -e "${YELLOW}Make sure the file exists and you have permission to read it${NC}"
    
    # Try to find the .env file
    LOCAL_ENV_FILE="./.env"
    if [ -f "$LOCAL_ENV_FILE" ] && [ -r "$LOCAL_ENV_FILE" ]; then
        if grep -q "CSRF_TRUSTED_ORIGINS" "$LOCAL_ENV_FILE"; then
            CSRF_CONFIG=$(grep "CSRF_TRUSTED_ORIGINS" "$LOCAL_ENV_FILE")
            echo -e "${YELLOW}Found CSRF configuration in local .env file:${NC}"
            echo -e "${YELLOW}$CSRF_CONFIG${NC}"
        fi
    fi
fi

echo -e "\n${BLUE}Step 5: Checking Nginx Proxy Manager configuration (if applicable)${NC}"
echo -e "${YELLOW}If you're using Nginx Proxy Manager:${NC}"
echo -e "${YELLOW}1. Make sure your domain points to the Nginx Proxy Manager server${NC}"
echo -e "${YELLOW}2. Ensure the proxy host is configured with:${NC}"
echo -e "${YELLOW}   - Forward Hostname / IP: $SERVER_IP${NC}"
echo -e "${YELLOW}   - Forward Port: 8001${NC}"
echo -e "${YELLOW}3. Verify the Advanced tab has the correct custom configuration${NC}"
echo -e "${YELLOW}   (See NPM_VISUAL_GUIDE.md for the recommended configuration)${NC}"

echo -e "\n${GREEN}Domain verification check complete!${NC}"
echo -e "${YELLOW}For detailed domain setup instructions, see DOMAIN_SETUP_GUIDE.md${NC}"
echo -e "${YELLOW}For Nginx Proxy Manager guidelines, see NPM_VISUAL_GUIDE.md${NC}"
