#!/bin/bash

echo "Attempting to auto-detect network configuration..."

# Check for curl
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed. Please install it (e.g., 'sudo apt-get install curl') and try again."
    exit 1
fi

# Detect Public IP
IP_PROVIDERS=("ifconfig.me" "icanhazip.com" "ipinfo.io/ip")
DETECTED_IP=""
for provider in "${IP_PROVIDERS[@]}"; do
    DETECTED_IP=$(curl -s "$provider")
    if [ -n "$DETECTED_IP" ]; then
        break
    fi
done

if [ -z "$DETECTED_IP" ]; then
    echo "Error: Could not automatically detect the public IP address."
    echo "Please edit config.sh and set SERVER_PUBLIC_IP manually."
    exit 1
fi

echo "Public IP detected: $DETECTED_IP"

# Detect Public NIC
DETECTED_NIC=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
if [ -z "$DETECTED_NIC" ]; then
    echo "Error: Could not automatically detect the public network interface."
    echo "Please edit config.sh and set SERVER_PUBLIC_NIC manually."
    exit 1
fi

echo "Public NIC detected: $DETECTED_NIC"

# Update config.sh
sed -i "s/SERVER_PUBLIC_IP=\".*\"/SERVER_PUBLIC_IP=\"$DETECTED_IP\"/" config.sh
sed -i "s/SERVER_PUBLIC_NIC=\".*\"/SERVER_PUBLIC_NIC=\"$DETECTED_NIC\"/" config.sh

echo "config.sh has been updated with the detected values."

