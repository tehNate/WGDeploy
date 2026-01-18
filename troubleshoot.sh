#!/bin/bash
set -e

# Source the configuration file to get server details
if [ -f "config.sh" ]; then
    source config.sh
else
    echo "Error: config.sh not found. Please ensure it's in the same directory."
    exit 1
fi

# Define SSH key path
SSH_KEY_PATH="$HOME/.ssh/id_rsa"

# Check if SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "Error: SSH private key not found at $SSH_KEY_PATH."
    echo "Please ensure you have generated an SSH key and run deploy.sh to copy it to the server."
    exit 1
fi

# Validate essential config variables
if [ "$SERVER_PUBLIC_IP" == "YOUR_SERVER_IP" ] || [ -z "$SERVER_PUBLIC_IP" ]; then
    echo "Error: SERVER_PUBLIC_IP is not set in config.sh. Please update config.sh."
    exit 1
fi
if [ -z "$REMOTE_USER" ]; then
    echo "Error: REMOTE_USER is not set in config.sh. Please update config.sh."
    exit 1
fi
if [ -z "$SSH_PORT" ]; then
    echo "Error: SSH_PORT is not set in config.sh. Please update config.sh."
    exit 1
fi
if [ -z "$SERVER_WG_NIC" ]; then
    echo "Error: SERVER_WG_NIC is not set in config.sh. Please update config.sh."
    exit 1
fi


echo "--- Running diagnostics on remote server ($REMOTE_USER@$SERVER_PUBLIC_IP:$SSH_PORT) ---"
echo "---------------------------------------------------------------------"

ssh -p "$SSH_PORT" -i "$SSH_KEY_PATH" "$REMOTE_USER@$SERVER_PUBLIC_IP" 'bash -s' <<EOF
echo "--- IP FORWARDING STATUS (IPv4 & IPv6) ---"
sysctl net.ipv4.ip_forward
sysctl net.ipv6.conf.all.forwarding

echo -e "\n--- NETWORK INTERFACES (Look for your public NIC: $SERVER_WG_NIC) ---"
ip a

echo -e "\n--- WIREGUARD SERVER CONFIGURATION (/etc/wireguard/$SERVER_WG_NIC.conf) ---"
cat /etc/wireguard/$SERVER_WG_NIC.conf

echo -e "\n--- IPTABLES NAT RULES ---"
sudo iptables -t nat -S

echo -e "\n--- IPTABLES FORWARD CHAIN RULES ---"
sudo iptables -S FORWARD

echo -e "\n--- IPTABLES MANGLE CHAIN RULES ---"
sudo iptables -t mangle -S

EOF

echo "---------------------------------------------------------------------"
echo "--- Diagnostics complete. Please review the output above. ---"
