#!/usr/bin/env bash
## Istio ports : 150NN : https://istio.io/latest/docs/ops/deployment/requirements/
## firewall-cmd is interface to firewalld
## HBONE : HTTP Based Overlay Network Environment

[[ $(systemctl is-active firewalld.service) == 'active' ]] || \
    sudo systemctl enable --now firewalld.service

zone=$(sudo firewall-cmd --get-active-zone |head -n1)

# Add http/https services to zone
sudo firewall-cmd --permanent --zone=$zone --add-service=http
sudo firewall-cmd --permanent --zone=$zone --add-service=https

### Istio sidecar proxy (Envoy)
svc=istio-envoy
at="--permanent --zone=$zone --service=$svc"
echo "=== Configure firewalld : $at ..."
# Define service (idempotent)
[[ $(sudo firewall-cmd --get-services |grep $svc) ]] || \
    sudo firewall-cmd --permanent --zone=$zone --new-service=$svc
sudo firewall-cmd $at --set-description="Add ports required of Istio sidecar proxy (Envoy) for HBONE via mTLS (H2) and cleartext (H2C), telemetry, and health checks"
sudo firewall-cmd $at --add-port=15001/tcp    # Istio Envoy outbound
sudo firewall-cmd $at --add-port=15006/tcp    # Istio Envoy inbound
sudo firewall-cmd $at --add-port=15008/tcp    # Istio HBONE mTLS (H2)
sudo firewall-cmd $at --add-port=15009/tcp    # Istio HBONE cleartext (H2C)
sudo firewall-cmd $at --add-port=15020/tcp    # Istio telemetry (merged)
sudo firewall-cmd $at --add-port=15021/tcp    # Istio Health checks
sudo firewall-cmd $at --add-port=15090/tcp    # Istio telemetry (Envoy)

# Add service
sudo firewall-cmd --permanent --zone=$zone --add-service=$svc

# Update and apply all rules under firewalld.service (sans systemctl)
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --info-service=$svc

### Istio control plane (istiod)
svc=istiod
at="--permanent --zone=$zone --service=$svc"
echo "=== Configure firewalld @ $at"
# Define service (idempotent)
[[ $(sudo firewall-cmd --get-services |grep $svc) ]] || \
    sudo firewall-cmd --permanent --zone=$zone --new-service=$svc
sudo firewall-cmd $at --set-description="Add ports required of Istio (istiod) for control plane monitoring and webhook, and for XDS and CA by cleartext, TLS, and mTLS"
sudo firewall-cmd $at --add-port=15010/tcp     # XDS and CA (cleartext)
sudo firewall-cmd $at --add-port=15012/tcp     # XDS and CA (TLS and mTLS)
sudo firewall-cmd $at --add-port=15014/tcp     # Istio Control Plane monitoring (HTTP)
sudo firewall-cmd $at --add-port=15017/tcp     # Istio Webhook ctnr port (HTTPS)

# Add service
sudo firewall-cmd --permanent --zone=$zone --add-service=$svc

# Update and apply all rules under firewalld.service (sans systemctl)
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --info-service=$svc
