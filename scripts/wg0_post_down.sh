#!/bin/bash
# wg-post-down.sh
# Description: This script removes the iptables rules for a WireGuard interface without peer isolation 

# Define the WireGuard interface (you can easily change this)
WG_INTERFACE="wg0"

# 1. Remove rule that allows traffic within the $WG_INTERFACE interface
iptables -D FORWARD -i $WG_INTERFACE -o $WG_INTERFACE -j ACCEPT

# 2. Remove rule that blocks traffic from $WG_INTERFACE to other WireGuard interfaces
iptables -D FORWARD -i $WG_INTERFACE -o wg+ -j DROP

# 3. Remove rule that blocks traffic from other WireGuard interfaces to $WG_INTERFACE
iptables -D FORWARD -i wg+ -o $WG_INTERFACE -j DROP

# 4. Remove rule that allows traffic from $WG_INTERFACE to external networks
iptables -D FORWARD -i $WG_INTERFACE -o eth+ -j ACCEPT

# 5. Remove rule that allows return traffic from external networks to $WG_INTERFACE
iptables -D FORWARD -i eth+ -o $WG_INTERFACE -m state --state ESTABLISHED,RELATED -j ACCEPT

# 6. Remove NAT (Masquerading) for traffic leaving $WG_INTERFACE
iptables -t nat -D POSTROUTING -o $WG_INTERFACE -j MASQUERADE

# 7. Remove NAT (Masquerading) for traffic leaving external networks (Ethernet interfaces)
iptables -t nat -D POSTROUTING -o eth+ -j MASQUERADE

# 8. Remove rule that allows all incoming traffic on $WG_INTERFACE
iptables -D INPUT -i $WG_INTERFACE -j ACCEPT

echo "WireGuard $WG_INTERFACE iptables rules removed."
