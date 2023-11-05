#!/usr/bin/env bash
#####################################################################
# Certs and related : kubeadm init phase ... 
#  
# - Run this script on ONLY the INIT NODE 
# - Idempotent. 
# 
# ARGs: K8S_INIT_NODE K8S_KUBEADM_CONFIG
#####################################################################

vm=$1
cfg=${2:-kubeadm-config.yaml}
host=$(hostname)
[[ "${vm,,}" == "${host,,}" ]] || {
    echo '=== Run this ONLY on K8S_INIT_NODE'
    
    exit 0
}

# Generate certs (once)
[[ -f /etc/kubernetes/pki/apiserver.key ]] || {
    echo 'Generating NEW cluster PKI @ /etc/kubernetes/pki/'
    sudo kubeadm init phase certs all --config $cfg
}

key=$(sudo kubeadm certs certificate-key)
hash=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
        |openssl rsa -pubin -outform der 2>/dev/null \
        |openssl dgst -sha256 -hex \
        |sed 's/^.* //' \
)
tkn=$(sudo kubeadm token generate)

echo "
export K8S_CERTIFICATE_KEY ?= $key
export K8S_CA_CERT_HASH    ?= sha256:$hash
export K8S_BOOTSTRAP_TOKEN ?= $tkn

"

exit 0 
######
