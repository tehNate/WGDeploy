#!/bin/bash

# ==> General settings
# The public IP address of your VPS.
SERVER_PUBLIC_IP="YOUR_SERVER_IP"
# The public network interface of your VPS.
# You can find this with `ip addr` or `ifconfig`. Common examples: eth0, ens3.
SERVER_PUBLIC_NIC="eth0"
# The private network interface for WireGuard.
SERVER_WG_NIC="wg0"
# The UDP port for WireGuard.
SERVER_WG_PORT="51820"

# ==> VPN network settings
# The IPv4 subnet for the VPN.
SERVER_WG_IPV4="10.66.66.1/24"
# The IPv6 subnet for the VPN (optional).
# SERVER_WG_IPV6="fd42:42:42::1/64"

# ==> DNS settings
# The DNS server(s) to be used by clients.
# You can use your own, or a public one like Cloudflare's (1.1.1.1) or Google's (8.8.8.8).
CLIENT_DNS="1.1.1.1, 1.0.0.1"

# ==> Remote server settings
# The user to connect to the remote server with.
REMOTE_USER="root"
# The SSH port for the remote server.
SSH_PORT="22"

# ==> For user management
# Directory to store client configs
CLIENT_CONFIG_DIR="client_configs"
