#!/usr/bin/env bash
###############################################################################
# firewalld : Calico (idempotent)
# https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements
# https://docs.tigera.io/calico/latest/reference/typha/overview
###############################################################################

[[ $(systemctl is-active firewalld.service) == 'active' ]] || \
    sudo systemctl enable --now firewalld.service

zone=$(sudo firewall-cmd --get-active-zone |head -n1)

## @ Worker nodes
svc=calico-worker
at="--permanent --zone=$zone --service=$svc"
echo "=== Configure firewalld : $at ..."
# Define service (idempotent)
[[ $(sudo firewall-cmd --get-services |grep $svc) ]] || \
    sudo firewall-cmd --permanent --zone=$zone --new-service=$svc
sudo firewall-cmd $at --set-description="Allow ports for BGP (Calico), VXLAN (Calico/Flannel), Calico Typha agent hosts, Wireguard (Calico)"
sudo firewall-cmd $at --add-port=179/tcp        # BGP (Calico)
sudo firewall-cmd $at --add-port=4789/udp       # VXLAN (Calico/Flannel)
sudo firewall-cmd $at --add-port=5473/tcp       # Calico Typha agent hosts
sudo firewall-cmd $at --add-port=51820/udp      # Wireguard (Calico)
sudo firewall-cmd $at --add-port=51821/udp      # Wireguard (Calico)
# Add service
sudo firewall-cmd --permanent --zone=$zone --add-service=$svc

# Update and apply all rules under firewalld.service (sans systemctl)
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --info-service=$svc

## @ Control nodes
svc=calico-control
at="--permanent --zone=$zone --service=$svc"
echo "=== Configure firewalld @ $at"
# Define service (idempotent)
[[ $(sudo firewall-cmd --get-services |grep $svc) ]] || \
    sudo firewall-cmd --permanent --zone=$zone --new-service=$svc
sudo firewall-cmd $at --set-description="Allow ports for BGP (Calico), VXLAN (Calico/Flannel), Wireguard (Calico)"
sudo firewall-cmd $at --add-port=179/tcp        # BGP (Calico)
sudo firewall-cmd $at --add-port=4789/udp       # VXLAN (Calico/Flannel)
sudo firewall-cmd $at --add-port=51820/udp      # Wireguard (Calico)
sudo firewall-cmd $at --add-port=51821/udp      # Wireguard (Calico)
# Add service
sudo firewall-cmd --permanent --zone=$zone --add-service=$svc

# Update and apply all rules under firewalld.service (sans systemctl)
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --info-service=$svc