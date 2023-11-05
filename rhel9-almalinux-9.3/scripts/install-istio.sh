#!/usr/bin/env bash
# Istio install
# https://istio.io/latest/docs/setup/install/helm/#prerequisites

# Platform Prerequisites
# https://istio.io/latest/docs/setup/platform-setup/prerequisites/
# Load kernel modules on boot
kernel_modules='
    br_netfilter
    iptable_mangle
    iptable_nat
    xt_REDIRECT
    xt_conntrack
    xt_owner
    xt_tcpudp
    xt_multiport
    bridge
    ip_tables
    nf_conntrack
    nf_conntrack_ipv4
    nf_nat
    nf_nat_ipv4
    nf_nat_redirect
    x_tables
'
printf "%s\n" $kernel_modules |sudo tee /etc/modules-load.d/istio.conf
# Load kernetl modules now
printf "%s\n" $kernel_modules |xargs -IX sudo modprobe X

[[ $(type -t helm) ]] || { echo '=== REQUIREs : helm';exit 99; }
# Install istio by Helm if not already
## https://artifacthub.io/packages/helm/istio-official/istiod
version_app='1.20.1'
version_chart='1.20.1'
## Intall istio charts repo
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
[[ $(kubectl get pod -n istio-system istiod 2>/dev/null) ]] && exit 0
## istiod : Install/Upgrade chart
#helm pull istio/istiod --version $version_chart # istiod-${version_chart}.tgz
#tar -xavf istiod-1.20.1.tgz # ./istiod/
helm upgrade istiod istio/istiod --install --version $version_chart --reuse-values --create-namespace -n istio-system
[[ $(kubectl get pod -n istio-gateway istio-ingressgateway 2>/dev/null) ]] && exit 0
## istio-ingressgateway : Install/Upgrade chart
helm upgrade istio-ingressgateway istio/gateway --install --version $version_chart --reuse-values --create-namespace -n istio-ingress