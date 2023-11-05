
## Istio ports : 150NN : https://istio.io/latest/docs/ops/deployment/requirements/
## firewall-cmd is interface to firewalld
## HBONE : HTTP Based Overlay Network Environment

[[ $(systemctl is-active firewalld.service) == 'active' ]] || \
    sudo systemctl --now enable firewalld.service

sudo firewall-cmd --permanent --zone=public --add-service=http
sudo firewall-cmd --permanent --zone=public --add-service=https

### Istio sidecar proxy (Envoy)
sudo firewall-cmd --permanent --new-service=istio-envoy
sudo firewall-cmd --permanent --service=istio-envoy --set-description="Istio sidecar proxy (Envoy)"
sudo firewall-cmd --permanent --service=istio-envoy --add-port=15001/tcp    # Istio Envoy outbound
sudo firewall-cmd --permanent --service=istio-envoy --add-port=15006/tcp    # Istio Envoy inbound
sudo firewall-cmd --permanent --service=istio-envoy --add-port=15008/tcp    # Istio HBONE mTLS (H2)
sudo firewall-cmd --permanent --service=istio-envoy --add-port=15009/tcp    # Istio HBONE cleartext (H2C)
sudo firewall-cmd --permanent --service=istio-envoy --add-port=15020/tcp    # Istio telemetry (merged)
sudo firewall-cmd --permanent --service=istio-envoy --add-port=15021/tcp    # Istio Health checks
sudo firewall-cmd --permanent --service=istio-envoy --add-port=15090/tcp    # Istio telemetry (Envoy)
sudo firewall-cmd --permanent --add-service=istio-envoy

### Istio control plane (istiod)
sudo firewall-cmd --permanent --new-service=istiod
sudo firewall-cmd --permanent --service=istiod --set-description="Istio control plane (istiod)"
sudo firewall-cmd --permanent --service=istiod --add-port=15010/tcp     # XDS and CA (cleartext)
sudo firewall-cmd --permanent --service=istiod --add-port=15012/tcp     # XDS and CA (TLS and mTLS)
sudo firewall-cmd --permanent --service=istiod --add-port=15014/tcp     # Istio Control Plane monitoring (HTTP)
sudo firewall-cmd --permanent --service=istiod --add-port=15017/tcp     # Istio Webhook ctnr port (HTTPS)
sudo firewall-cmd --permanent --add-service=istiod

