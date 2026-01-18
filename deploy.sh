#!/bin/bash

# Source the configuration file
if [ -f "config.sh" ]; then
    source config.sh
else
    echo "Error: config.sh not found."
    exit 1
fi

# Check if SERVER_PUBLIC_IP is set
if [ "$SERVER_PUBLIC_IP" == "YOUR_SERVER_IP" ]; then
    echo "Error: Please edit config.sh and set your SERVER_PUBLIC_IP."
    exit 1
fi

# --- SSH Key Setup ---
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "SSH key not found. Generating a new one..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
fi

# Check if ssh-copy-id is installed
if ! [ -x "$(command -v ssh-copy-id)" ]; then
    echo 'Error: ssh-copy-id is not installed. Please install it to continue.' >&2
    exit 1
fi

echo "Copying SSH public key to the server. You may be asked for the password."
ssh-copy-id -p "$SSH_PORT" "$REMOTE_USER@$SERVER_PUBLIC_IP"

# SSH command to run on the remote server
SSH_CMD="ssh -p $SSH_PORT -i $SSH_KEY_PATH $REMOTE_USER@$SERVER_PUBLIC_IP"

# Commands to be executed on the remote server
REMOTE_SCRIPT=$(cat <<EOF
# Update and install WireGuard
apt-get update
apt-get install -y wireguard iptables qrencode

# Generate server keys
wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
chmod 600 /etc/wireguard/privatekey

# Create WireGuard configuration
cat > /etc/wireguard/$SERVER_WG_NIC.conf <<EOCONF
[Interface]
Address = $SERVER_WG_IPV4
$( [ -n "$SERVER_WG_IPV6" ] && echo "Address = $SERVER_WG_IPV6" )
SaveConfig = true
PrivateKey = \$(cat /etc/wireguard/privatekey)
ListenPort = $SERVER_WG_PORT
PostUp = iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o $SERVER_PUBLIC_NIC -j MASQUERADE
$( [ -n "$SERVER_WG_IPV6" ] && echo "PostUp = ip6tables -A FORWARD -i %i -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $SERVER_PUBLIC_NIC -j MASQUERADE" )
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $SERVER_PUBLIC_NIC -j MASQUERADE
$( [ -n "$SERVER_WG_IPV6" ] && echo "PostDown = ip6tables -D FORWARD -i %i -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $SERVER_PUBLIC_NIC -j MASQUERADE" )
EOCONF

# Enable IP forwarding
sed -i '/net.ipv4.ip_forward=1/s/^#//' /etc/sysctl.conf
sed -i '/net.ipv6.conf.all.forwarding=1/s/^#//' /etc/sysctl.conf
sysctl -p

# Start and enable WireGuard
systemctl enable wg-quick@$SERVER_WG_NIC
systemctl restart wg-quick@$SERVER_WG_NIC
wg-quick save $SERVER_WG_NIC

# Open WireGuard UDP port in iptables
iptables -A INPUT -i $SERVER_PUBLIC_NIC -p udp --dport $SERVER_WG_PORT -j ACCEPT
# Save iptables rules for persistence (Debian/Ubuntu specific)
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
netfilter-persistent save

echo "WireGuard server deployed successfully."
EOF
)

# Execute the remote script
$SSH_CMD "$REMOTE_SCRIPT"

# Make manage-user.sh executable
chmod +x manage-user.sh 2>/dev/null

echo "Deployment script finished."
echo "Passwordless SSH has been set up for future connections."
echo "You can now use ./manage-user.sh without a password."
