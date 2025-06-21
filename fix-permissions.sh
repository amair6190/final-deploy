#!/bin/bash

# Quick fix for permission error during deployment
# Run this if the deployment fails at the chown step

echo "🔧 Fixing permission issue..."

# Create the solvit user if it doesn't exist
sudo useradd -r -d /opt/solvit-ticketing -s /bin/false solvit 2>/dev/null || echo "User solvit already exists"

# Set proper permissions
sudo chmod -R 755 /opt/solvit-ticketing/staticfiles/
sudo chmod -R 755 /opt/solvit-ticketing/media/
sudo chown -R solvit:solvit /opt/solvit-ticketing/

echo "✅ Permissions fixed! You can continue with the deployment."
