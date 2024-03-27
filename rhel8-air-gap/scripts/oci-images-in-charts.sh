#!/usr/bin/env bash
#######################################################################
# Extract all images of Helm charts (*.tgz) and values.yaml under PWD:
#######################################################################

images(){
    [[ -f $1 ]] && cat $1 |grep -e repository: -e registry: -e image: -e tag:
}
export -f images 

[[ -d $1 ]] && pushd $1 

# find . -type f -iname '*.tgz' -exec /bin/bash -c '
#     images="$(helm template $1 |yq .spec.template.spec.containers[].image |sort -u)"
#     [[ "$images" ]] && printf "=== Images @ %s :\n%s\n\n"  $1 "$images"
# ' _ {} \;

# find . -type f -iname 'values.yaml' -exec /bin/bash -c '
#     echo @ $1;cat $1 |grep -e repository: -e registry: -e image: -e tag:
# ' _ {} \;

find . -type f -iname 'values.yaml' -exec /bin/bash -c 'images $1' _ {} \;

find . -type f -iname '*.tgz' -exec /bin/bash -c '
    images="$(helm template $1 |yq .spec.template.spec.containers[].image |sort -u)"
    [[ "$images" ]] && echo "$images" |grep -v -- --- 
' _ {} \; 2>&1 |grep -v ' ' |sort -u

    # printf "\n%s\n"  "=== @ $1" && helm template $1 |yq .spec.template.spec.containers[].image |sort -u

# images="$(helm template $1 |yq .spec.template.spec.containers[].image |sort -u)"
# [[ "$images" ]] && printf "=== Images @ %s :\n%s\n\n"  $1 "$images"

popd 
exit 0 
######

# Result (edited) @ download-bins.sh

busybox:latest
docker:20.10
docker.io/library/busybox:1.36.1
ghcr.io/aquasecurity/trivy-operator:0.18.4
ghcr.io/spiffe/spire-agent:1.8.5
ghcr.io/spiffe/spire-server:1.8.5
hashicorp/vault:1.15.2
hashicorp/vault-k8s:1.3.1
kubesphere/fluent-bit:v2.2.0
kubesphere/fluentd:v1.15.3
kubesphere/fluent-operator:v2.7.0
lemonldapng/lemonldap-ng-controller:0.2.0
longhornio/longhorn-manager:v1.6.0
longhornio/longhorn-ui:v1.6.0
nginx:latest
node_metrics:fb.metrics
quay.io/cilium/certgen:v0.1.9
quay.io/cilium/cilium-envoy:v1.27.3-713b673cccf1af661efd75ca20532336517ddcb9
quay.io/cilium/cilium-etcd-operator:v2.0.7
quay.io/cilium/cilium:v1.15.1
quay.io/cilium/cilium:v1.15.1@sha256:351d6685dc6f6ffbcd5451043167cfa8842c6decf80d8c8e426a417c73fb56d4
quay.io/cilium/clustermesh-apiserver:v1.15.1
quay.io/cilium/hubble-relay:v1.15.1
quay.io/cilium/hubble-ui-backend:v0.13.0
quay.io/cilium/hubble-ui:v0.13.0
quay.io/cilium/operator-generic:v1.15.1
quay.io/cilium/operator-generic:v1.15.1@sha256:819c7281f5a4f25ee1ce2ec4c76b6fbc69a660c68b7825e9580b1813833fa743
quay.io/cilium/operatorv1.15.1
quay.io/cilium/startup-script:62093c5c233ea914bfa26a10ba41f8780d9b737f
registry.k8s.io/defaultbackend-amd64:1.5
registry.k8s.io/ingress-nginx/controller:v1.9.6
registry.k8s.io/ingress-nginx/controller:v1.9.6@sha256:1405cc613bd95b2c6edd8b2a152510ae91c7e62aea4698500d23b2145960ab9c
registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20231226-1a7112e06
registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20231226-1a7112e06@sha256:25d6a5f11211cc5c3f9f2bf552b585374af287b4debf693cacbe2da47daa5084
registry.k8s.io/ingress-nginx/mytestmodule:v1.0.0
registry.k8s.io/ingress-nginx/opentelemetry:v20230721-3e2062ee5
registry.k8s.io/metrics-server/metrics-server:v0.7.0
registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2

