#!/bin/bash

# Source the configuration file
if [ -f "config.sh" ]; then
    source config.sh
else
    echo "Error: config.sh not found."
    exit 1
fi

# Function to show usage
usage() {
    echo "Usage: $0 [create|remove] [username]"
    exit 1
}

# Check for correct number of arguments
if [ "$#" -ne 2 ]; then
    usage
fi

ACTION=$1
USERNAME=$2
SSH_CMD="ssh -p $SSH_PORT $REMOTE_USER@$SERVER_PUBLIC_IP"

# Create a directory for client configs if it doesn't exist
mkdir -p $CLIENT_CONFIG_DIR

# --- CREATE USER ---
if [ "$ACTION" == "create" ]; then
    # Generate client keys
    CLIENT_PRIVATE_KEY=$(wg genkey)
    CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

    # Determine the next available IP
    LAST_IP_OCTET=$($SSH_CMD "grep -oP 'AllowedIPs = 10.66.66.\\K([0-9]+)' /etc/wireguard/$SERVER_WG_NIC.conf | sort -n | tail -n 1")
    if [ -z "$LAST_IP_OCTET" ]; then
        # First user
        NEXT_IP_OCTET=2
    else
        NEXT_IP_OCTET=$((LAST_IP_OCTET + 1))
    fi
    CLIENT_WG_IPV4="10.66.66.$NEXT_IP_OCTET/32"

    # Add peer to server config
    $SSH_CMD "echo -e \"\n# Client: $USERNAME\n[Peer]\nPublicKey = $CLIENT_PUBLIC_KEY\nAllowedIPs = $CLIENT_WG_IPV4\" >> /etc/wireguard/$SERVER_WG_NIC.conf"

    # Reload WireGuard to apply changes
    $SSH_CMD "systemctl reload wg-quick@$SERVER_WG_NIC"

    # Create client config file
    cat > "$CLIENT_CONFIG_DIR/$USERNAME.conf" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_WG_IPV4
DNS = $CLIENT_DNS

[Peer]
PublicKey = $($SSH_CMD "cat /etc/wireguard/publickey")
Endpoint = $SERVER_PUBLIC_IP:$SERVER_WG_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

    echo "User $USERNAME created."
    echo "Config file saved to: $CLIENT_CONFIG_DIR/$USERNAME.conf"
    echo ""
    echo "You can now transfer this file to your devices and import it into the WireGuard app."
    echo ""

    # Check if qrencode is installed and display QR code if it is
    if command -v qrencode &> /dev/null; then
        echo "For mobile clients, you can also scan this QR code:"
        qrencode -t ansiutf8 < "$CLIENT_CONFIG_DIR/$USERNAME.conf"
    else
        echo "To display a QR code for mobile clients, install 'qrencode' (e.g., 'sudo apt-get install qrencode')."
    fi

# --- REMOVE USER ---
elif [ "$ACTION" == "remove" ]; then
    if [ ! -f "$CLIENT_CONFIG_DIR/$USERNAME.conf" ]; then
        echo "Error: Client config for $USERNAME not found."
        exit 1
    fi

    # Get the user's IP from the local config file
    CLIENT_WG_IPV4=$(grep 'Address' "$CLIENT_CONFIG_DIR/$USERNAME.conf" | awk '{print $3}')
    
    # Get the user's public key from the server config
    CLIENT_PUBLIC_KEY=$($SSH_CMD "grep -B 2 \"AllowedIPs = $CLIENT_WG_IPV4\" /etc/wireguard/$SERVER_WG_NIC.conf | grep 'PublicKey' | awk '{print \$3}'")

    if [ -z "$CLIENT_PUBLIC_KEY" ]; then
        echo "Error: Could not find user $USERNAME on the server."
        exit 1
    fi

    # Remove peer from server config
    $SSH_CMD "sed -i \"/# Client: $USERNAME/,/AllowedIPs = $CLIENT_WG_IPV4/d\" /etc/wireguard/$SERVER_WG_NIC.conf"

    # Reload WireGuard to apply changes
    $SSH_CMD "systemctl reload wg-quick@$SERVER_WG_NIC"

    # Remove local client config
    rm "$CLIENT_CONFIG_DIR/$USERNAME.conf"

    echo "User $USERNAME removed."

else
    usage
fi