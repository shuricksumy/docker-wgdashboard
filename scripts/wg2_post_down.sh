#!/bin/bash
# wg-post-down-block-external.sh
# Description: This script removes the iptables rules that block all traffic except inside WireGuard

# Define the WireGuard interface
WG_INTERFACE="wg2"

# Define the subnet for WireGuard peers
SUBNET="10.8.16.0/24"

# 1. Remove rule that allows traffic within the WireGuard interface
iptables -D FORWARD -i $WG_INTERFACE -o $WG_INTERFACE -s $SUBNET -d $SUBNET -j ACCEPT

# 2. Remove rule that blocks traffic to/from external interfaces
iptables -D FORWARD -i $WG_INTERFACE -o eth+ -j DROP
iptables -D FORWARD -i eth+ -o $WG_INTERFACE -j DROP

# 3. Remove rule that blocks traffic between WireGuard interfaces
iptables -D FORWARD -i $WG_INTERFACE -o wg+ -j DROP
iptables -D FORWARD -i wg+ -o $WG_INTERFACE -j DROP

# 4. Remove rule that allows all incoming traffic on $WG_INTERFACE
iptables -D INPUT -i $WG_INTERFACE -j ACCEPT

echo "WireGuard interface $WG_INTERFACE iptables rules for blocking external traffic removed."
