#!/usr/bin/env bash
# FAILing : This may not be a valid method.
# See https://kubernetes.io/docs/tasks/tls/manual-rotation-of-ca-certificates/
# See https://chat.openai.com/share/dc7592bd-98f1-4355-ab3c-900e03797c85

# Remove all Static Pod manifests
sudo mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/
# Wait for Pods to terminate
while true 
do 
    flag=true
    for pod in kube-apiserver etcd kube-control kube-scheduler
    do 
        [[ $(crictl pods |grep $pod ) ]] && {
            flag=false
            echo "  Waiting for $pod Pod to terminate"
        }
    done 
    [[ $flag ]] && break 
done 
# Stop kubelet.service
sudo systemctl stop kubelet.service
# Delete all PKI
find /etc/kubernetes/pki -type f -exec sudo rm -rf {} \;
# Delete kubeconfig
sudo mv /etc/kubernetes/admin.conf /etc/kubernetes/admin.conf.old

ver='1.28.5'
vipp='192.168.0.100:8443'
pnet='10.10.0.0/16'
snet='10.55.0.0/16'
ip=$(ip -4 -color=never route |cut -d' ' -f9 |head -n 1)

# Generate self-signed CA (.crt, .key) files
flags='ca etcd-ca front-proxy-ca'
for flag in $flags
do
    sudo kubeadm init phase certs $flag -v5 \
        --kubernetes-version $ver \
        |& tee kubeadm.init.phase.certs.$flag.$(hostname).log
done

# Generate self-signed ServiceAccount (SA) (.crt, .key) files
flag='sa'
sudo kubeadm init phase certs $flag -v5 \
    |& tee kubeadm.init.phase.certs.$flag.$(hostname).log

# Generate all (other) certs
flag=all
sudo kubeadm init phase certs $flag -v5 \
    --kubernetes-version "$ver" \
    --control-plane-endpoint "$vipp" \
    --apiserver-advertise-address=$ip \
    --service-cidr "$snet" \
    |& tee kubeadm.init.phase.certs.$flag.$(hostname).log

# NOTE: --apiserver-cert-extra-sans strings

# Generate new kubeconfig (admin.conf)
sudo kubeadm init phase kubeconfig admin -v5 \
    --kubernetes-version $ver \
    --control-plane-endpoint "$vipp" \
    --apiserver-advertise-address=$ip \
    |& tee kubeadm.init.phase.kubeconfig.admin.$(hostname).log

# Configure client
sudo cp -p /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config 

# Restore all Static Pod manifests
sudo mv /etc/kubernetes/*.yaml /etc/kubernetes/manifests/
