#!/bin/bash
set -euxo pipefail

# Input arguments
DO_VPN_PUBLIC_IP="$1"
DO_VPN_TUNNEL_IP="$2"
REMOTE_VPN_PUBLIC_IP="$3"
REMOTE_VPN_TUNNEL_IP="$4"
REMOTE_CIDR="$5"

# Get metadata
ANCHOR_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/anchor_ipv4/address)
ANCHOR_IP_GATEWAY=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/anchor_ipv4/gateway)

# Outbound traffic via Reserved IP
echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
yq -i "(.network.ethernets.eth0.routes[] | select(.to == \"0.0.0.0/0\")).via = \"${ANCHOR_IP_GATEWAY}\"" /etc/netplan/50-cloud-init.yaml
netplan apply

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1

# NAT setup
iptables -t nat -A POSTROUTING -s 10.0.0.0/8 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.16.0.0/12 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.0.0/16 -o eth0 -j MASQUERADE

# IPsec config
sed -i 's/\t# uniqueids/\tuniqueids/g' /etc/ipsec.conf
echo "include /etc/ipsec.d/*.conf" >> /etc/ipsec.conf
echo "net.ipv4.conf.default.rp_filter = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.accept_source_route = 0" >> /etc/sysctl.conf
sysctl -p
systemctl enable netfilter-persistent.service

## Tunnel Interface
ip link add Tunnel1 type vti local "${ANCHOR_IP}" remote "${REMOTE_VPN_PUBLIC_IP}" key 100
ip addr add ${DO_VPN_TUNNEL_IP} remote ${REMOTE_VPN_TUNNEL_IP} dev Tunnel1
ip link set Tunnel1 up mtu 1419
ip route add "${REMOTE_CIDR}" dev Tunnel1


## Prevent auto route installation by strongSwan
sed -i "s/\s# install_routes = yes/\ install_routes = no/g" /etc/strongswan.d/charon.conf

## Iptables mangle config
iptables -t mangle -A FORWARD -o Tunnel1 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
iptables -t mangle -A INPUT -p esp -s "${REMOTE_VPN_PUBLIC_IP}" -d "${DO_VPN_PUBLIC_IP}" -j MARK --set-xmark 100

## More sysctl config
echo "net.ipv4.conf.Tunnel1.rp_filter=2" >> /etc/sysctl.conf
echo "net.ipv4.conf.Tunnel1.disable_policy=1" >> /etc/sysctl.conf
echo "net.ipv4.conf.eth0.disable_xfrm=1" >> /etc/sysctl.conf
echo "net.ipv4.conf.eth0.disable_policy=1" >> /etc/sysctl.conf
sysctl -p

## Persistence
iptables-save > /etc/iptables/rules.v4

# Add Tunnel1 interface persistence
cat <<EOF >> /etc/network/interfaces
auto Tunnel1
iface Tunnel1 inet manual
  pre-up ip link add Tunnel1 type vti local ${ANCHOR_IP} remote ${REMOTE_VPN_PUBLIC_IP} key 100
  pre-up ip addr add ${DO_VPN_TUNNEL_IP} remote ${REMOTE_VPN_TUNNEL_IP} dev Tunnel1
  up ip link set Tunnel1 up mtu 1419
  up ip route add ${REMOTE_CIDR} dev Tunnel1
  down ip route del ${REMOTE_CIDR} dev Tunnel1
EOF

systemctl restart vpc-peering.service
ipsec stop
ipsec start