#!/usr/bin/env bash
###################################################################################
# firewalld : Cilium : Setup Master/Worker identically  (idempotent)
# https://docs.cilium.io/en/stable/operations/system_requirements/#firewall-rules
###################################################################################

[[ $(systemctl is-active firewalld.service) == 'active' ]] || \
    sudo systemctl enable --now firewalld.service

## @ Identical Master/Worker config 
zone=$(sudo firewall-cmd --get-active-zone |head -n1)
[[ $zone ]] || {
    echo 'FAIL @ --get-active-zone'
    exit 1
}
svc=calico 
at="--permanent --zone=$zone --service=$svc"
echo "=== Configure firewalld : $at ..."

# Define service (idempotent)
[[ $(sudo firewall-cmd --get-services |grep $svc) ]] || \
    sudo firewall-cmd --permanent --zone=$zone --new-service=$svc

sudo firewall-cmd $at --set-description="Allow ports for Cilium : cilium-operator, cilium-agent, Hubble Relay and server, Spire Agent, Prometheus metrics, and Wireguard tunnel"

sudo firewall-cmd $at --add-port=4240/tcp   # cluster health checks (cilium-health)
sudo firewall-cmd $at --add-port=4244/tcp   # Hubble server
sudo firewall-cmd $at --add-port=4245/tcp   # Hubble Relay
sudo firewall-cmd $at --add-port=4250/tcp   # Mutual Authentication port
sudo firewall-cmd $at --add-port=4251/tcp   # Spire Agent health check port (listening on 127.0.0.1 or ::1)
sudo firewall-cmd $at --add-port=6060/tcp   # cilium-agent pprof server (listening on 127.0.0.1)
sudo firewall-cmd $at --add-port=6061/tcp   # cilium-operator pprof server (listening on 127.0.0.1)
sudo firewall-cmd $at --add-port=6062/tcp   # Hubble Relay pprof server (listening on 127.0.0.1)
sudo firewall-cmd $at --add-port=9878/tcp   # cilium-envoy health listener (listening on 127.0.0.1)
sudo firewall-cmd $at --add-port=9879/tcp   # cilium-agent health status API (listening on 127.0.0.1 and/or ::1)
sudo firewall-cmd $at --add-port=9890/tcp   # cilium-agent gops server (listening on 127.0.0.1)
sudo firewall-cmd $at --add-port=9891/tcp   # operator gops server (listening on 127.0.0.1)
sudo firewall-cmd $at --add-port=9893/tcp   # Hubble Relay gops server (listening on 127.0.0.1)
sudo firewall-cmd $at --add-port=9962/tcp   # cilium-agent Prometheus metrics
sudo firewall-cmd $at --add-port=9963/tcp   # cilium-operator Prometheus metrics
sudo firewall-cmd $at --add-port=9964/tcp   # cilium-envoy Prometheus metrics
sudo firewall-cmd $at --add-port=51871/udp  # WireGuard encryption tunnel endpoint

# Add service
sudo firewall-cmd --permanent --zone=$zone --add-service=$svc

# Update and apply all rules under firewalld.service (sans systemctl)
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --info-service=$svc
