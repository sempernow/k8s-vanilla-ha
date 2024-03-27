#!/usr/bin/env bash
###############################################################################
# firewalld : Kubernetes (idempotent)
## https://docs.oracle.com/en/operating-systems/olcne/1.1/start/ports.html
## https://kubernetes.io/docs/reference/networking/ports-and-protocols/
###############################################################################

[[ $(systemctl is-active firewalld.service) == 'active' ]] || \
    sudo systemctl enable --now firewalld.service

device=cni0
zone=$(sudo firewall-cmd --get-active-zone |head -n1)

## @ Worker nodes
svc='k8s-workers'
at="--permanent --zone=$zone --service=$svc"
echo "=== Configure firewalld @ $at"
# Define service (idempotent)
[[ $(sudo firewall-cmd --get-services |grep $svc) ]] || \
    sudo firewall-cmd --permanent --zone=$zone --new-service=$svc
sudo firewall-cmd $at --set-description="Allow ports and interface required by Kubernetes Worker nodes"
[[ -f /etc/sysconfig/network-scripts/ifcfg-$device ]] \
    && sudo firewall-cmd $at --add-interface=$device
sudo firewall-cmd $at --add-port=443/tcp            # kube-apiserver inbound
sudo firewall-cmd $at --add-port=10250/tcp          # kubelet API inbound
sudo firewall-cmd $at --add-port=10255/tcp          # kubelet Node/Pod CIDRs (v1.23.6+)
sudo firewall-cmd $at --add-port=10256/tcp          # GKE LB Health checks
sudo firewall-cmd $at --add-port=30000-32767/tcp    # NodePort Services inbound

# Add service
sudo firewall-cmd --permanent --zone=$zone --add-service=$svc

# Update and apply all rules under firewalld.service (sans systemctl)
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --info-service=$svc

## @ Control nodes
svc=k8s-control
at="--permanent --zone=$zone --service=$svc"
echo "=== Configure firewalld @ $at"
# Define service (idempotent)
[[ $(sudo firewall-cmd --get-services |grep $svc) ]] || \
    sudo firewall-cmd --permanent --zone=$zone --new-service=$svc
sudo firewall-cmd $at --set-description="Allow ports and interface required by Kubernetes Control nodes"
[[ -f /etc/sysconfig/network-scripts/ifcfg-$device ]] \
    && sudo firewall-cmd $at --add-interface=$device
sudo firewall-cmd $at --add-port=443/tcp            # kube-apiserver inbound
sudo firewall-cmd $at --add-port=2379-2380/tcp      # etcd, kube-apiserver inbound
sudo firewall-cmd $at --add-port=6443/tcp           # kube-apiserver inbound
sudo firewall-cmd $at --add-port=10250/tcp          # kubelet API inbound
sudo firewall-cmd $at --add-port=10255/tcp          # kubelet Node/Pod CIDRs (v1.23.6+)
sudo firewall-cmd $at --add-port=10256/tcp          # GKE LB Health checks
sudo firewall-cmd $at --add-port=10257/tcp          # kube-controller-manager inbound
sudo firewall-cmd $at --add-port=10259/tcp          # kube-scheduler inbound
# @ Kubernetes versions below 1.17
#sudo firewall-cmd $at --add-port=10251/tcp          # kube-scheduler (moved to 10259)
#sudo firewall-cmd $at --add-port=10252/tcp          # kube-controller-manager (moved to 10257)

# Add service
sudo firewall-cmd --permanent --zone=$zone --add-service=$svc

# Update and apply all rules under firewalld.service (sans systemctl)
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --info-service=$svc