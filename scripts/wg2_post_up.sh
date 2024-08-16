#!/bin/bash
# wg-post-up-block-external.sh
# Description: This script sets up iptables rules to block all traffic except inside WireGuard

# Define the WireGuard interface
WG_INTERFACE="wg3"

# Define the subnet for WireGuard peers (change according to your setup)
SUBNET="10.8.16.0/24"

# 1. Allow traffic within the WireGuard interface (inside the same subnet)
iptables -A FORWARD -i $WG_INTERFACE -o $WG_INTERFACE -s $SUBNET -d $SUBNET -j ACCEPT

# 2. Block traffic to/from external interfaces (eth+)
iptables -A FORWARD -i $WG_INTERFACE -o eth+ -j DROP
iptables -A FORWARD -i eth+ -o $WG_INTERFACE -j DROP

# 3. Block traffic between WireGuard interfaces
iptables -A FORWARD -i $WG_INTERFACE -o wg+ -j DROP
iptables -A FORWARD -i wg+ -o $WG_INTERFACE -j DROP

# 4. Allow incoming traffic on the $WG_INTERFACE interface (WireGuard traffic)
iptables -I INPUT 1 -i $WG_INTERFACE -j ACCEPT

echo "WireGuard interface $WG_INTERFACE isolated with only internal traffic allowed."
