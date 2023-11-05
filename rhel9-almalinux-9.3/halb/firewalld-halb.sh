#!/usr/bin/env bash
###############################################################################
# firewalld : HALB built of HAProxy and Keepalived (idempotent)
###############################################################################

[[ $(systemctl is-active firewalld.service) == 'active' ]] || \
    sudo systemctl enable --now firewalld.service

#zone=$(sudo firewall-cmd --get-active-zone |head -n1)
zone=public

svc=halb
# vip="${HALB_VIP:-192.168.0.100}"
# vip6="${HALB_VIP6:-::ffff:c0a8:64}"
# vport="${HALB_PORT:-8443}"
# device="${HALB_DEVICE:-eth0}" # Network interface common to all LB nodes
vip="${1}"
vip6="${2}"
vport="${3}"
device="${4}" # Network interface common to all LB nodes

at="--permanent --zone=$zone --service=$svc"
echo "Configure firewalld : service @ $at"

#echo "vip: $1, vip6: $2, vport: $3, dev: $4"
#exit

# Define service (idempotent)
[[ $(sudo firewall-cmd --get-services |grep $svc) ]] || \
    sudo firewall-cmd --permanent --zone=$zone --new-service=$svc
sudo firewall-cmd $at --set-description="Add ports required of HAProxy frontend and backend HTTP(S) listeners"
## Allow HAProxy listen to HTTP(S) traffic 
sudo firewall-cmd $at --add-port=80/tcp
sudo firewall-cmd $at --add-port=443/tcp
sudo firewall-cmd $at --add-port=6443/tcp
sudo firewall-cmd $at --add-port=$vport/tcp

# Add SERVICE
sudo firewall-cmd --permanent --zone=$zone --add-service=$svc

# Add RICH RULEs to zone (cannot be scoped to service)
# (See `man firewalld.richlanguage`)

## VIP : Allow traffic to/from VIP address by either IPv4 or IPv6 
at="--permanent --zone=$zone"
echo "Configure firewalld : rich rules @ $at"
sudo firewall-cmd $at --add-rich-rule='rule family="ipv4" source address="'$vip'" accept'
sudo firewall-cmd $at --add-rich-rule='rule family="ipv6" source address="'$vip6'" accept'
## VRRP : Multicast
sudo firewall-cmd $at --add-rich-rule='rule family="ipv4" destination address="224.0.0.0/4" accept' 
## VRRP : Protocol 112
#sudo firewall-cmd $at --add-rich-rule='rule protocol value="vrrp" accept'
#sudo firewall-cmd $at --add-rich-rule='rule family="ipv4" source address="'$vip'" protocol value="vrrp" accept'

# Add DIRECT RULEs (cannot be scoped to zone or service)
## VRRP : Protocol 112
# iptables -I INPUT -p 112 -j ACCEPT
# iptables -I OUTPUT -p 112 -j ACCEPT
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p vrrp -j ACCEPT
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 -p vrrp -j ACCEPT

# Update firewalld.service sans restart 
sudo firewall-cmd --reload

