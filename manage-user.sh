#!/bin/bash
set -e

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

# Check if qrencode is installed
if ! [ -x "$(command -v qrencode)" ]; then
  echo 'Error: qrencode is not installed.' >&2
  exit 1
fi

ACTION=$1
USERNAME=$2
# This script assumes you have set up passwordless SSH authentication.
# Run the deploy.sh script to set this up.
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
SSH_CMD="ssh -p $SSH_PORT -i $SSH_KEY_PATH $REMOTE_USER@$SERVER_PUBLIC_IP"
LOCK_FILE="/tmp/wg_user_lock"

# --- LOCKING FUNCTIONS ---
# Function to acquire a lock
acquire_lock() {
    echo "Acquiring lock..."
    exec 200>$LOCK_FILE
    flock -n 200 || { echo "Failed to acquire lock, another instance may be running."; exit 1; }
}

# Function to release a lock
release_lock() {
    flock -u 200
    echo "Lock released."
}


# Create a directory for client configs if it doesn't exist
mkdir -p $CLIENT_CONFIG_DIR

# --- CREATE USER ---
if [ "$ACTION" == "create" ]; then
    acquire_lock

    # Generate client keys
    CLIENT_PRIVATE_KEY=$(wg genkey)
    CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

    # Determine the next available IP on the server
    LAST_IP_OCTET=$($SSH_CMD "wg show $SERVER_WG_NIC allowed-ips | awk '{print \$2}' | cut -d . -f 4 | cut -d / -f 1 | sort -n | tail -n 1")
    if [ -z "$LAST_IP_OCTET" ]; then
        # First user
        NEXT_IP_OCTET=2
    else
        NEXT_IP_OCTET=$((LAST_IP_OCTET + 1))
    fi
    CLIENT_WG_IPV4="10.66.66.$NEXT_IP_OCTET/32"

    # Add peer to server config using wg set to avoid restart
    $SSH_CMD "wg set $SERVER_WG_NIC peer $CLIENT_PUBLIC_KEY allowed-ips $CLIENT_WG_IPV4"
    $SSH_CMD "wg-quick save $SERVER_WG_NIC"


    # Get server public key
    SERVER_PUBLIC_KEY=$($SSH_CMD "wg show $SERVER_WG_NIC public-key")

    # Create client config file
    cat > "$CLIENT_CONFIG_DIR/$USERNAME.conf" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_WG_IPV4
DNS = $CLIENT_DNS

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_PUBLIC_IP:$SERVER_WG_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

    release_lock

    echo "User $USERNAME created."
    echo "Config file: $CLIENT_CONFIG_DIR/$USERNAME.conf"
    echo "QR Code for mobile client:"
    qrencode -t ansiutf8 < "$CLIENT_CONFIG_DIR/$USERNAME.conf"

# --- REMOVE USER ---
elif [ "$ACTION" == "remove" ]; then
    if [ ! -f "$CLIENT_CONFIG_DIR/$USERNAME.conf" ]; then
        echo "Error: Client config for $USERNAME not found."
        exit 1
    fi

    CLIENT_PUBLIC_KEY=$(grep 'PrivateKey' "$CLIENT_CONFIG_DIR/$USERNAME.conf" | awk '{print $3}' | wg pubkey)

    if [ -z "$CLIENT_PUBLIC_KEY" ];
    then
        echo "Error: Could not get public key from client config."
        exit 1
    fi

    acquire_lock

    # Remove peer from server using wg set
    $SSH_CMD "wg set $SERVER_WG_NIC peer $CLIENT_PUBLIC_KEY remove"
    $SSH_CMD "wg-quick save $SERVER_WG_NIC"

    release_lock

    # Remove local client config
    rm "$CLIENT_CONFIG_DIR/$USERNAME.conf"

    echo "User $USERNAME removed."

else
    usage
fi