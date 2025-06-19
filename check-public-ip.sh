#!/bin/bash

# Simple script to check your server's public IP address
# This IP address should be used in your DNS configuration

echo "Checking your server's public IP address..."
PUBLIC_IP=$(curl -s ifconfig.me)

echo "Your server's public IP address is: $PUBLIC_IP"
echo ""
echo "DNS Configuration Instructions:"
echo "------------------------------"
echo "1. Log in to your domain registrar (e.g., Namecheap, GoDaddy)"
echo "2. Find the DNS settings for your domain"
echo "3. Create or update the following A records:"
echo "   - Type: A"
echo "   - Host: @ (or leave blank for the root domain)"
echo "   - Value: $PUBLIC_IP"
echo "   - TTL: 3600 (or automatic)"
echo ""
echo "4. If you want 'www' subdomain to work:"
echo "   - Type: A"
echo "   - Host: www"
echo "   - Value: $PUBLIC_IP"
echo "   - TTL: 3600 (or automatic)"
echo ""
echo "DNS changes may take up to 24-48 hours to propagate worldwide,"
echo "but typically take effect within a few minutes to a few hours."
