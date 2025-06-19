#!/bin/bash

# Quick fix for DB_NAME environment variable issue
# Run on target server: 10.0.0.18

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root or with sudo"
    exit 1
fi

# Check if .env file exists and add DB_NAME if missing
ENV_FILE="/opt/solvit-ticketing/.env"
if [ -f "$ENV_FILE" ]; then
    echo "Checking .env file for DB_NAME..."
    if ! grep -q "^DB_NAME=" "$ENV_FILE"; then
        echo "Adding DB_NAME to .env file..."
        echo -e "\n# Database Configuration\nDB_NAME=solvit_ticketing" >> "$ENV_FILE"
        echo "Added DB_NAME=solvit_ticketing to .env file"
    else
        echo "DB_NAME already exists in .env file"
    fi
    
    # Check for other essential variables
    if ! grep -q "^DB_USER=" "$ENV_FILE"; then
        echo "Adding DB_USER to .env file..."
        echo "DB_USER=solvit" >> "$ENV_FILE"
    fi
    
    if ! grep -q "^DB_PASSWORD=" "$ENV_FILE"; then
        echo "Adding DB_PASSWORD to .env file..."
        echo "DB_PASSWORD=solvitpass" >> "$ENV_FILE"
    fi
    
    if ! grep -q "^DB_HOST=" "$ENV_FILE"; then
        echo "Adding DB_HOST to .env file..."
        echo "DB_HOST=localhost" >> "$ENV_FILE"
    fi
    
    if ! grep -q "^DB_PORT=" "$ENV_FILE"; then
        echo "Adding DB_PORT to .env file..."
        echo "DB_PORT=5432" >> "$ENV_FILE"
    fi
    
    echo "Setting ownership and permissions..."
    chown solvit:solvit "$ENV_FILE"
    chmod 600 "$ENV_FILE"
else
    echo "Error: .env file not found at $ENV_FILE"
    echo "Creating new .env file..."
    
    cat > "$ENV_FILE" << EOL
# SolvIT Ticketing System Environment Variables

# Database Configuration
DB_NAME=solvit_ticketing
DB_USER=solvit
DB_PASSWORD=solvitpass
DB_HOST=localhost
DB_PORT=5432

# Django Configuration
DEBUG=False
SECRET_KEY=defaultsecretkey-please-change-in-production
ALLOWED_HOSTS=127.0.0.1,localhost,10.0.0.18,support.solvitservices.com,www.support.solvitservices.com
SECURE_SSL_REDIRECT=False
CSRF_TRUSTED_ORIGINS=http://127.0.0.1:8001,http://10.0.0.18:8001,https://support.solvitservices.com,http://support.solvitservices.com
ADMIN_URL=admin/

# Alternative database configuration
DATABASE_URL=postgres://solvit:solvitpass@localhost/solvit_ticketing
EOL

    echo "New .env file created"
    chown solvit:solvit "$ENV_FILE"
    chmod 600 "$ENV_FILE"
fi

echo "Restarting services..."
systemctl restart solvit-ticketing
systemctl restart nginx
echo "Done! Check if the application is now working"
