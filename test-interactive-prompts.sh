#!/bin/bash

# Test script to demonstrate the interactive prompts

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🚀 SolvIT Django Ticketing System - Interactive Deployment Test"
echo "============================================================="
echo ""
echo -e "${BLUE}📋 This is how the interactive prompts will work:${NC}"
echo ""

# Database Configuration Test
echo -e "${BLUE}📋 Database Configuration${NC}"
echo "Please provide the following database details:"
echo -e "${YELLOW}Note: Database names can only contain letters, numbers, and underscores (no hyphens or spaces)${NC}"
echo ""

# Validate database name
while true; do
    read -p "Enter database name [default: solvit_ticketing]: " DB_NAME
    DB_NAME=${DB_NAME:-solvit_ticketing}
    
    # Check if database name is valid (only letters, numbers, underscores)
    if [[ "$DB_NAME" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        break
    else
        echo -e "${RED}Invalid database name. Use only letters, numbers, and underscores. Must start with a letter or underscore.${NC}"
        echo -e "${YELLOW}Example: solvit_ticketing, my_database, ticketing_system${NC}"
    fi
done

# Validate database username
while true; do
    read -p "Enter database username [default: solvit_user]: " DB_USER
    DB_USER=${DB_USER:-solvit_user}
    
    # Check if username is valid (only letters, numbers, underscores)
    if [[ "$DB_USER" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        break
    else
        echo -e "${RED}Invalid username. Use only letters, numbers, and underscores. Must start with a letter or underscore.${NC}"
        echo -e "${YELLOW}Example: solvit_user, admin_user, db_user${NC}"
    fi
done

while true; do
    read -s -p "Enter database password: " DB_PASSWORD
    echo ""
    read -s -p "Confirm database password: " DB_PASSWORD_CONFIRM
    echo ""
    if [[ "$DB_PASSWORD" == "$DB_PASSWORD_CONFIRM" ]]; then
        if [[ ${#DB_PASSWORD} -lt 8 ]]; then
            echo -e "${RED}Password must be at least 8 characters long. Please try again.${NC}"
        else
            break
        fi
    else
        echo -e "${RED}Passwords do not match. Please try again.${NC}"
    fi
done

echo -e "${GREEN}✅ Database configuration set: $DB_NAME with user: $DB_USER${NC}"
echo ""

# Superuser Configuration Test
echo -e "${BLUE}👤 Django Superuser Configuration${NC}"
echo "Please provide the following admin user details:"
echo ""

read -p "Enter admin username [default: admin]: " ADMIN_USERNAME
ADMIN_USERNAME=${ADMIN_USERNAME:-admin}

read -p "Enter admin email [default: admin@solvit.com]: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@solvit.com}

read -p "Enter admin mobile number [optional]: " ADMIN_MOBILE
ADMIN_MOBILE=${ADMIN_MOBILE:-1234567890}

while true; do
    read -s -p "Enter admin password: " ADMIN_PASSWORD
    echo ""
    read -s -p "Confirm admin password: " ADMIN_PASSWORD_CONFIRM
    echo ""
    if [[ "$ADMIN_PASSWORD" == "$ADMIN_PASSWORD_CONFIRM" ]]; then
        if [[ ${#ADMIN_PASSWORD} -lt 8 ]]; then
            echo -e "${RED}Password must be at least 8 characters long. Please try again.${NC}"
        else
            break
        fi
    else
        echo -e "${RED}Passwords do not match. Please try again.${NC}"
    fi
done

echo -e "${GREEN}✅ Admin user configuration set: $ADMIN_USERNAME${NC}"
echo ""

# Summary
echo -e "${BLUE}📋 Configuration Summary:${NC}"
echo "================================"
echo -e "${YELLOW}Database:${NC}"
echo "  Name: $DB_NAME"
echo "  User: $DB_USER"
echo "  Password: [HIDDEN]"
echo ""
echo -e "${YELLOW}Admin User:${NC}"
echo "  Username: $ADMIN_USERNAME"
echo "  Email: $ADMIN_EMAIL"
echo "  Mobile: $ADMIN_MOBILE"
echo "  Password: [HIDDEN]"
echo ""
echo -e "${GREEN}🎉 Configuration complete! The actual deployment would proceed with these settings.${NC}"
