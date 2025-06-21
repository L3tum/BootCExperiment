#!/bin/bash

firewall-cmd --new-zone=tailscale
firewall-cmd --zone=tailscale --add-interface=tailscale0
firewall-cmd --zone=public --add-masquerade
firewall-cmd --new-policy=tailscaleegress
firewall-cmd --policy=tailscaleegress --add-ingress-zone=tailscale --set-target=ACCEPT
firewall-cmd --policy=tailscaleegress --add-egress-zone=external --set-target=ACCEPT
firewall-cmd --zone=tailscale --add-port=443/tcp
firewall-cmd --zone=tailscale --add-port=41641/udp
firewall-cmd --zone=tailscale --add-port=3478/udp

ACTIVE_INTERFACE=$(ip -o route get 8.8.8.8 | cut -f 5 -d " ")
MTU_SIZE=1400
if [ -z "$ACTIVE_INTERFACE" ]; then
    echo "No active network interface found. Exiting."
    exit 1
fi
# Set MTU size, comment the following line to use the default system value
sudo ip link set dev "$ACTIVE_INTERFACE" mtu $MTU_SIZE
# Enable UDP GRO Forwarding
sudo ethtool -K "$ACTIVE_INTERFACE" rx-udp-gro-forwarding on rx-gro-list off
