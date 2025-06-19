#!/bin/bash

# Test script for SolvIT CSRF Configuration
# This script tests whether your Django application is properly configured for CSRF with a proxy

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Testing CSRF configuration for SolvIT Ticketing System...${NC}"

# Check if CSRF_TRUSTED_ORIGINS is properly set in .env
if grep -q "CSRF_TRUSTED_ORIGINS" .env; then
    echo -e "${GREEN}✓ CSRF_TRUSTED_ORIGINS found in .env file${NC}"
    grep "CSRF_TRUSTED_ORIGINS" .env
else
    echo -e "${RED}✗ CSRF_TRUSTED_ORIGINS not found in .env file${NC}"
    echo -e "${YELLOW}Adding CSRF_TRUSTED_ORIGINS to .env...${NC}"
    echo "CSRF_TRUSTED_ORIGINS=https://support.solvitservices.com,https://www.support.solvitservices.com,http://support.solvitservices.com,http://www.support.solvitservices.com" >> .env
    echo -e "${GREEN}✓ Added CSRF_TRUSTED_ORIGINS to .env file${NC}"
fi

# Check if CSRF_TRUSTED_ORIGINS is properly set in Django settings
if grep -q "CSRF_TRUSTED_ORIGINS" it_ticketing_system/settings_production.py; then
    echo -e "${GREEN}✓ CSRF_TRUSTED_ORIGINS found in Django settings${NC}"
else
    echo -e "${RED}✗ CSRF_TRUSTED_ORIGINS not found in Django settings${NC}"
    echo -e "${YELLOW}Please verify that CSRF_TRUSTED_ORIGINS is properly configured in Django settings${NC}"
    echo "Add the following to it_ticketing_system/settings_production.py:"
    echo '
# CSRF Trusted Origins (for cross-origin requests with domains)
CSRF_TRUSTED_ORIGINS = env.list("CSRF_TRUSTED_ORIGINS", default=[
    "https://support.solvitservices.com",
    "https://www.support.solvitservices.com",
])
'
fi

# Check if Django is configured to use HTTPS
echo -e "${YELLOW}Checking HTTPS settings...${NC}"
if grep -q "SECURE_SSL_REDIRECT=True" .env; then
    echo -e "${GREEN}✓ SSL redirect is enabled${NC}"
else
    echo -e "${YELLOW}! SSL redirect is not enabled - this is fine if you're using HTTP for testing${NC}"
fi

# Test if Django server is running
echo -e "${YELLOW}Testing connection to Django server...${NC}"
if curl -s http://localhost:8001 > /dev/null; then
    echo -e "${GREEN}✓ Django server is accessible on port 8001${NC}"
else
    echo -e "${RED}✗ Cannot connect to Django server on port 8001${NC}"
    echo -e "${YELLOW}Check if the server is running:${NC} sudo systemctl status solvit-ticketing"
fi

# Provide information for NPM configuration
echo -e "\n${YELLOW}Nginx Proxy Manager Configuration:${NC}"
echo -e "Forward Hostname / IP: $(hostname -I | awk '{print $1}')"
echo -e "Forward Port: 8001"
echo -e "Domain Names: support.solvitservices.com www.support.solvitservices.com"

echo -e "\n${GREEN}Test completed. Now set up Nginx Proxy Manager using the provided guide.${NC}"
