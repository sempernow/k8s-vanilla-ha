#!/usr/bin/env bash
# Following FHS best practices, 
# Binaries here are installed to /usr/local/bin/,
# whereas binaries of RPMs are installed to /usr/bin/ .

[[ -d $1 ]] || {
    echo "Directory does NOT EXIST : $1"
    exit 0
}
pushd "$1"
#cd '/tmp/k8s-air-gap-install'

folder()
{
    [[ $1 ]] && {
        echo "$(find . -maxdepth 1 -type d -iname "${1}*" -printf "$(pwd)/%P\n" |tail -n1)"
    }
}

[[ -f Makefile ]] || {
    echo "
        USAGE : ${BASH_SOURCE##*/} /path/to/k8s-air-gap-install
    "
    exit 1
}

ARCH="amd64"

# @ kubelet, kubeadm, kubectl
[[ $(type -t kubelet) ]] || {
    echo "=== @ kubelet, kubeadm, kubectl"
    dir=/usr/local/bin 
    
    sudo cp kubernetes/kubelet $dir/
    sudo cp kubernetes/kubeadm $dir/
    sudo cp kubernetes/kubectl $dir/

    kubelet --version
    kubeadm version
    kubectl version --client=true
}
# @ kubelet.service
[[ -d /etc/systemd/system/kubelet.service.d ]] || {
    echo "=== @ kubelet.service"
    dir=$(which kubelet)
    dir=${dir%/*}
    svc1=kubernetes/systemd/kubelet.service
    svc2=kubernetes/systemd/10-kubeadm.conf

    sed "s:/usr/bin:${dir}:g" $svc1 |sudo tee /etc/systemd/system/kubelet.service
    sudo mkdir -p /etc/systemd/system/kubelet.service.d
    sed "s:/usr/bin:${dir}:g" $svc2 |sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
}

# @ runc, cni-plugins, containerd, cri-tools
# See install-containerd-air-gap.sh

# @ cri-dockerd (CRI-compliant shim)
[[ $(type -t cri-dockerd) ]] || {
    echo "=== @ cri-dockerd (CRI-compliant shim)"
    src='docker/cri-dockerd'
    sudo cp $src/cri-dockerd /usr/local/bin/
    cri-dockerd --version
}
# @ cri-docker.service
[[ -f /usr/lib/systemd/system/cri-docker.service ]] || {
    echo "=== @ cri-docker.service, cri-docker.socket"
    src='docker/cri-dockerd'
    # Configure systemd units for cri-dockerd (service and socket)
    sed 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' $src/cri-docker.service \
        |sudo tee /usr/lib/systemd/system/cri-docker.service
    sed 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' $src/cri-docker.socket \
        |sudo tee /usr/lib/systemd/system/cri-docker.socket

    #sudo chown root:root /usr/lib/systemd/system/cri-docker.*
    #sudo chmod 0644 /usr/lib/systemd/system/cri-docker.*

    ls -hl /usr/lib/systemd/system/cri-docker*

    # Enable/Start : Docker should be running first.
    # sudo systemctl daemon-reload
    # sudo systemctl enable --now cri-docker.socket
    # sudo systemctl enable --now cri-docker.service
}

# @ Docker CE
[[ $(type -t docker) ]] || {
    echo "=== @ Docker CE"
    find docker -maxdepth 1 -type f -exec sudo cp {} /usr/local/bin/ \;
    ls -hl /usr/local/bin/
    docker info
}

# @ etcd, etcdctl, etcdutl 
[[ $(type -t etcd) ]] || {
    echo "=== @ etcd, etcdctl, etcdutil"
    src=etcd
    printf "%s\n" etcd etcdctl etcdutl |xargs -I{} sudo cp $src/{} /usr/local/bin/
    etcd --version
    etcdctl version
    etcdutl version
    # # Test : How-to
    # echo '
    #     Test etcd (standalone, per-node) using: ssh $vm /bin/bash -s < etcd-test.sh
    # '
}

# @ Trivy
[[ $(type -t trivy) ]] || {
    echo "=== @ trivy"
    sudo cp $(folder trivy)/trivy /usr/local/bin/
    ls -hl /usr/local/bin/tr*
    trivy -v
}

# @ Helm
[[ $(type -t helm) ]] || {
    echo "=== @ helm"
    sudo cp helm/helm /usr/local/bin/
    ls -hl /usr/local/bin/he*
    helm version
}

# @ yq
[[ $(type -t yq) ]] || {
    echo "=== @ yq"
    BINARY=yq_linux_amd64
    sudo cp yq/${BINARY} /usr/bin/yq 
    sudo chown root:root /usr/bin/yq 

    sudo cp yq/yq.1.gz /usr/share/man/man1/
    #ls -hl /usr/bin/y*
    #ls -hl /usr/share/man/man1/y*
    man -w yq 
    yq --version 
}

# @ Cilium
[[ $(type -t cilium) ]] || {
    # @ CLI
    folder=$(folder cilium)
    echo "=== @ cilium CLI"

    sudo cp $folder/cilium-cli/cilium /usr/local/bin/
    ls -hl /usr/local/bin/cilium
    cilium version --client

    # https://github.com/cilium/cilium
    # https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#create-the-cluster
    ## Install cilium using CLI
    #cilium install --version $ver --set image.useDigest=false
    #cilium install --version=1.14.1 --helm-set ipam.operator.clusterPoolIPv4PodCIDRList=["10.42.0.0/16"]  --helm-set image.tag=1.14.1

    #cilium status --wait
    #cilium connectivity test
}


exit 0

[[ $(helm list -n kube-system |grep cilium) ]] && {
    helm list -n kube-system |grep cilium 
} || {
    # # Cilium chart
    # ver=1.15.1
    # repo=cilium
    # chart=cilium
    # # Download  
    # # https://artifacthub.io/packages/helm/cilium/cilium/
    # helm pull --version $ver $repo/$chart
    # tar -xaf cilium-$ver.tgz 
    ## Install using helm

    echo "=== @ cilium/cilium : install by Helm"
    folder=$(folder cilium)
    tarball="$(find $folder -type f -iname '*.tgz')"
    [[ -d $folder/cilium ]] && tar -xaf $tarball -C $folder 
    helm upgrade cilium $folder/cilium/ --install --namespace kube-system
    cilium status 
}




## TODO ... all remaining 

popd

exit 0
######

#####################################
# Copied from standard-install dir
#####################################

# nerdctl : Docker-compatible CLI for containerd 
# https://github.com/containerd/nerdctl
# https://github.com/containerd/nerdctl/releases
# Full : bin/ (binaries), lib/ (systemd configs), libexec/ (cni plugins), share/ (docs)
ver='1.7.3'
mkdir -p nerdctl
pushd nerdctl
tarball=nerdctl-full-${ver}-linux-${ARCH}.tar.gz
base_url=https://github.com/containerd/nerdctl/releases/download/v${ver}
#target_parent=/usr/local/bin
wget -nv $base_url/$tarball #&& tar -xaf $tarball 
popd 


# Calico by Manifest Method
ver='3.27.0'
base=https://raw.githubusercontent.com/projectcalico/calico/v${ver}/manifests 
# https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises
wget -nv -O calico-${ver}.yaml $base/calico.yaml
# k apply -f calico-${ver}.yaml

# Cilium binary
# https://github.com/cilium/cilium
# https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#create-the-cluster
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=${ARCH}
[[ "$(uname -m)" = "aarch64" ]] && CLI_ARCH=arm64
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
tar -xaf cilium-linux-${CLI_ARCH}.tar.gz 
    #cilium install --version $ver 
    #cilium status --wait
    #cilium connectivity test
# Cilium chart
ver=1.14.4 
repo=cilium
chart=cilium
# Download  
# https://artifacthub.io/packages/helm/cilium/cilium/
helm pull --version $ver $repo/$chart
tar -xaf cilium-$ver.tgz 


# Ingress NGINX Controller 
# https://github.com/kubernetes/ingress-nginx
# https://kubernetes.github.io/ingress-nginx/deploy/#bare-metal-clusters
mkdir -p ingress-nginx-controller
pushd ingress-nginx-controller
ver='1.9.5'
yaml="ingress-nginx-${ver}-k8s.baremetal.deploy.yaml"
wget -nv -O $yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v${ver}/deploy/static/provider/baremetal/deploy.yaml
# Helm chart
# https://github.com/kubernetes/ingress-nginx
repo='ingress-nginx'
chart='ingress-nginx'
ver='4.9.0' # Chart
#ver='1.9.5' # App
release='ingress-nginx'
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm pull --version $ver $repo/$chart
popd

# Istio : Image dependencies are effectively hidden, eg, "istio/proxyv2" is a bogus image
# istioctl method
# https://istio.io/latest/docs/setup/getting-started/
# https://github.com/istio/istio/releases/
mkdir -p istioctl-method
pushd istioctl-method
ver='1.20.2' # App / Chart (same)
tarball="istio-${ver}-linux-${ARCH}.tar.gz"
wget -nv https://github.com/istio/istio/releases/download/$ver/$tarball
tar xaf $tarball
popd 
# Helm method 
# https://artifacthub.io/packages/helm/istio-official/istiod
mkdir -p helm-method
pushd helm-method
repo='istio-official'
chart='istiod' 
ver='1.20.2' # App / Chart (same)
helm pull --version $ver $repo/$chart
popd

# Kustomize
# https://github.com/kubernetes-sigs/kustomize/releases
ver='5.3.0'
tarball="kustomize_v${ver}_linux_${ARCH}.tar.gz"
url=https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${ver}/$tarball
wget -nv $url && tar xvaf $tarball

# Metrics Server 
# https://artifacthub.io/packages/helm/metrics-server/metrics-server
ver=3.11.0 # App version 0.6.4
helm pull metrics-server/metrics-server --version $ver 
tar -xaf metrics-server-$ver.tgz
#find metrics-server -type f -iname '*.yaml' -exec cat {} \; |grep -A1 repository

# fluent-operator : Fluentd + Fluent Bit
# https://github.com/fluent/fluent-operator
# https://artifacthub.io/packages/helm/fluent/fluent-operator
ver=2.7.0
helm repo add fluent https://fluent.github.io/helm-charts
helm pull --version=$ver charts/fluent-operator

# StorageClass

# nfs-client : nfs-subdir-external-provisioner
# https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner
# https://artifacthub.io/packages/helm/nfs-subdir-external-provisioner/nfs-subdir-external-provisioner
repo='nfs-subdir-external-provisioner'
chart='nfs-subdir-external-provisioner'
ver='4.0.18' # Chart
#ver='4.0.2' # App
#release='nfs-client'
helm pull --version $ver $repo/$chart

# local-storage : rancher/local-path-provisioner
# https://github.com/rancher/local-path-provisioner
# https://artifacthub.io/packages/helm/containeroo/local-path-provisioner
repo='nfs-subdir-external-provisioner'
chart='nfs-subdir-external-provisioner'
ver='4.0.18' # Chart
#ver='4.0.2' # App
#release='nfs-client'
helm pull --version $ver $repo/$chart

# longhorn : 
# https://longhorn.io/docs/1.5.3/deploy/install/install-with-kubectl/
yaml=longhorn.yaml
url=https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/$yaml
wget -nv $url


exit 0

# nerdctl : Docker-compatible CLI for containerd 
# https://github.com/containerd/nerdctl
# https://github.com/containerd/nerdctl/releases
# Full : bin/ (binaries), lib/ (systemd configs), libexec/ (cni plugins), share/ (docs)
ver='1.7.3'
mkdir -p nerdctl
pushd nerdctl
tarball=nerdctl-full-${ver}-linux-${ARCH}.tar.gz
base_url=https://github.com/containerd/nerdctl/releases/download/v${ver}
#target_parent=/usr/local/bin
wget -nv $base_url/$tarball #&& tar -xaf $tarball 
popd 


exit 0
######

##########################
# Pull & Save all images
##########################

# Single image
img='redis:7.2.3-alpine3.18'
docker pull $img
tar=${img////.}
[[ -f ${tar/:/_}.tar ]] || docker save $img -o ${tar/:/_}.tar


# K8s : kubeadm config images : pull using docker
ver=1.29.2
list="kubeadm-v${ver}-config.images.list.log"
conf='kubeadm-config-images.yaml'
cat <<-EOH |tee $conf
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: $ver
imageRepository: registry.k8s.io
EOH

kubeadm config images list --config $conf |tee $list

cat $list |xargs -IX docker pull X
cat $list |xargs -IX /bin/bash -c '
    tar=${1////.}
    [[ -f ${tar/:/_}.tar ]] || docker save $1 -o ${tar/:/_}.tar
' _ X 

# YAML images (Helm charts and others)

# To extract ALL chart images (name and tag) must recover name and tag from separate lines
# Manually gather across all charts (per $chart_root) using BOTH of the following methods:
list=chart.images.log
find $chart_root -type f -iname '*.yaml' -exec cat {} \; |grep -A1 repository: \
    |cut -d':' -f2 \
    |sed 's,",,g' \
    |grep -v -- -- \
    |grep -v -- { \
    |xargs -n 2 printf "%s:%s\n" \
    |sort -u \
    |tee -a $list
# AND 
find $chart_root -type f -iname '*.yaml' -exec cat {} \; |grep image: \
    |grep -v -- { \
    |cut -d':' -f2,3,4,5 \
    |sed '/^$/d' \
    |sort -u \
    |sed 's, ,,g' \
    |sed 's,",,g' \
    |tee -a $list 

# The $list contains a manual gather across all charts using the above method.
cat $list |xargs -IX docker pull X
cat $list |xargs -IX /bin/bash -c '
    tar=${1////.}
    [[ -f ${tar/:/_}.tar ]] || docker save $1 -o ${tar/:/_}.tar
' _ X 


# Utility images

list=utility.images.log
cat <<EOH |tee $list
abox:1.0.2
almalinux:9.3-20231124
alpine:3.18.5
busybox:1.36.1-musl
debian:bookworm-20240110
golang:1.21.6-alpine3.19
golang:1.21.6-bookworm
httpd:2.4.58-alpine3.18
mariadb:11.2.2-jammy
nginx:1.25.3-alpine3.18
node:21.6.0-alpine3.19
node:21.6.0-bookworm
node:21.6.0-bookworm-slim
postgres:16.1-alpine3.18
postgres:16.1-bookworm
python:3.12.1-alpine3.19
python:3.12.1-bookworm
redis:7.2.3-alpine3.18
tomcat:10.1.18-jdk21
ubuntu:noble-20240114
EOH
cat $list |xargs -IX docker pull X
cat $list |xargs -IX /bin/bash -c '
    tar=${1////.}
    [[ -f ${tar/:/_}.tar ]] || docker save $1 -o ${tar/:/_}.tar
' _ X 

# StorageClass

# nfs-client : nfs-subdir-external-provisioner
img='registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2'
tar=${img////.}
docker save $img -o ${tar/:/_}.tar

# local-path : rancher/local-path-provisioner:v0.0.26
yaml=local-path-storage.yaml
cat $yaml |grep image: \
    |awk -F ':' '{printf "%s:%s\n" ,$2,$3 }' \
    |sed 's/^ //' \
    |sort -u 

$list=local-path.images.log
cat <<EOH |tee $list
rancher/local-path-provisioner:v0.0.26
busybox:latest
EOH
cat $list |xargs -IX docker pull X
cat $list |xargs -IX /bin/bash -c '
    tar=${1////.}
    [[ -f ${tar/:/_}.tar ]] || docker save $1 -o ${tar/:/_}.tar
' _ X 

# longhorn : 
# https://longhorn.io/docs/1.5.3/deploy/install/install-with-kubectl/
yaml=longhorn.yaml
cat $yaml |grep image: \
    |awk -F ':' '{printf "%s:%s\n" ,$2,$3 }' \
    |sed 's/^ //' \
    |sort -u 

$list=longhorn.images.log
cat <<EOH |tee $list
longhornio/longhorn-manager:v1.5.3
longhornio/longhorn-ui:v1.5.3
EOH
cat $list |xargs -IX docker pull X
cat $list |xargs -IX /bin/bash -c '
    tar=${1////.}
    [[ -f ${tar/:/_}.tar ]] || docker save $1 -o ${tar/:/_}.tar
' _ X 

# Cilium
list=cilium.images.log
cat <<EOH |tee $list
quay.io/cilium/cilium:v1.14.4
quay.io/cilium/certgen:v0.1.9
quay.io/cilium/hubble-relay:v1.14.4
quay.io/cilium/hubble-ui-backend:v0.12.1
quay.io/cilium/hubble-ui:v0.12.1
quay.io/cilium/cilium-envoy:v1.26.6-ff0d5d3f77d610040e93c7c7a430d61a0c0b90c1
quay.io/cilium/cilium-etcd-operator:v2.0.7
quay.io/cilium/operator:v1.14.4
quay.io/cilium/startup-script:62093c5c233ea914bfa26a10ba41f8780d9b737f
quay.io/cilium/clustermesh-apiserver:v1.14.4
quay.io/coreos/etcd:v3.5.4
quay.io/cilium/kvstoremesh:v1.14.4
ghcr.io/spiffe/spire-agent:1.6.3
ghcr.io/spiffe/spire-server:1.6.3
EOH
cat $list |xargs -IX docker pull X
cat $list |xargs -IX /bin/bash -c '
    tar=${1////.}
    [[ -f ${tar/:/_}.tar ]] || docker save $1 -o ${tar/:/_}.tar
' _ X 

# Compress all in-place (to `.tar.gz`)
find . -type f -iname '*.tar' -exec gzip {} \+

# Decompress all (to `.tar`) 
find . -type f -iname '*.tar' -exec gzip -d {} \+

# Docker load
find . -type f -iname '*.tar' -exec docker load -i {} \;

# Docker push to registry
find . -type f -iname '*.tar' -exec docker push {} \;
