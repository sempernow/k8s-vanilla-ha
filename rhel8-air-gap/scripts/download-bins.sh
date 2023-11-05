#!/usr/bin/env bash
###########################################################################
# Download apps that install by methods other than package manager (RPMs)
# - binaries
# - helm charts
# - configurations for systemd and others 
#
# Idempotent 
#
# Binaries not of a pkg mgr should be installed into /usr/local/bin/ .
# See FHS : https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard
###########################################################################

ARCH='amd64'
#mkdir -p binaries
#pushd binaries

images(){
    [[ -f $1 ]] && cat $1 |grep -e repository: -e registry: -e image: -e tag:
}
export -f images 

ok(){
    # @ kubelet, kubeadm, kubectl
    # https://kubernetes.io/releases/
    # https://www.downloadkubernetes.com/
    # https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
    ver="$(curl -sSL https://dl.k8s.io/release/stable.txt)" # @ v1.29.2
    [[ $(./kubernetes-$ver/kubeadm version |grep $ver) ]] && return 0
    mkdir -p kubernetes-$ver
    pushd kubernetes-$ver
    base="https://dl.k8s.io/release/${ver}/bin/linux/${ARCH}"
    wget -nv ${base}/kubeadm
    wget -nv ${base}/kubelet
    wget -nv ${base}/kubectl
    ## K8s-core images
    reg='registry.k8s.io'
    #reg=$docker_distribution_registry # Air-gap bootstrap (lifeboat)
    conf="kubeadm-${ver}-config-images.yaml"
	cat <<-EOH |tee $conf
	apiVersion: kubeadm.k8s.io/v1beta3
	kind: ClusterConfiguration
	kubernetesVersion: $ver
	imageRepository: $reg
	EOH
    #sudo kubeadm config images pull --config $conf \
    ./kubeadm config images list --config $conf |tee ${conf/.yaml/.log}
    # @ kubelet.service (systemd)
    mkdir -p systemd
    pushd systemd
    ver='0.16.2' # Has no releases page
    base="https://raw.githubusercontent.com/kubernetes/release/v${ver}/cmd/krel/templates/latest"
    wget -nv "${base}/kubelet/kubelet.service" 
    #|sed "s:/usr/bin:${DOWNLOAD_DIR}:g" |sudo tee /etc/systemd/system/kubelet.service
    #sudo mkdir -p /etc/systemd/system/kubelet.service.d
    #curl -sSL "${base}/kubeadm/10-kubeadm.conf" 
    wget -nv "${base}/kubeadm/10-kubeadm.conf" 
    #|sed "s:/usr/bin:${DOWNLOAD_DIR}:g" |sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    popd
    popd
}
ok 

ok(){
    # @ cni-plugins (kubernetes-cni)
    # https://github.com/containernetworking/plugins/releases
    ver="1.4.0" 
    #dir="/opt/cni/bin" # REF @ install
    dir="cni-plugins-$ver"
    [[ -d $dir && $(./$dir/loopback 2>&1 |grep $ver) ]] && return 0
    mkdir -p $dir
    tarball="cni-plugins-linux-${ARCH}-v${ver}.tgz" 
    url="https://github.com/containernetworking/plugins/releases/download/v${ver}/$tarball"
    wget -nv $url && tar -xavf $tarball -C $dir
}
ok

ok(){
    # @ containerd binaries
    # https://github.com/containerd/containerd/blob/main/docs/getting-started.md
    # https://github.com/containerd/containerd/releases
    ver='1.7.14' # NEWER than Docker CE version 
    dir="containerd-${ver}"
    tarball="${dir}-linux-${ARCH}.tar.gz"
    [[ -d $dir && $(./$dir/containerd --version 2>&1 |grep $ver) ]] && return 0
    base=https://github.com/containerd/containerd/releases/download/v$ver
    wget -nv $base/$tarball && tar -xaf $tarball && rm $tarball
    sleep 3 # Allow for network-volume latency
    mv bin $dir
    # @ containerd.service 
    mkdir -p $dir/systemd
    url=https://raw.githubusercontent.com/containerd/containerd/main/containerd.service 
    #target_parent=/usr/local/lib/systemd/system
    wget -nv -O $dir/systemd/containerd.service $url
}
ok

ok(){
    # @ runc : low-level utility : used by containerd
    # https://github.com/opencontainers/runc/releases
    # https://github.com/containerd/containerd/blob/main/docs/getting-started.md
    ver='1.1.12'
    dir=runc-$ver
    [[ -d $dir && $(./$dir/runc --version 2>&1 |grep $ver) ]] && return 0
    url=https://github.com/opencontainers/runc/releases/download/v${ver}/runc.$ARCH
    mkdir -p $dir
    wget -nv -O $dir/runc $url #&& sudo install -m 0755 runc /usr/local/sbin/
}
ok

ok(){
    # @ cri-tools
    # https://github.com/kubernetes-sigs/cri-tools/releases
    ver="1.29.0"
    dir="cri-tools-$ver"
    [[ -d $dir && $(./$dir/runc --version 2>&1 |grep $ver) ]] && return 0
    mkdir -p $dir
    base_url="https://github.com/kubernetes-sigs/cri-tools/releases/download/v$ver"
    #target_parent=/usr/local/bin
    tarball="crictl-v${ver}-linux-${ARCH}.tar.gz" 
    wget -nv "$base_url/$tarball" && tar -xavf $tarball -C $dir
    tarball="critest-v${ver}-linux-${ARCH}.tar.gz"
    wget -nv "$base_url/$tarball" && tar -xavf $tarball -C $dir
}
ok

ok(){
    # @ Docker binaries
    ver='25.0.4'
    dir="docker-$ver"
    [[ -d $dir && $(./$dir/docker --version 2>&1 |grep $ver) ]] && return 0
    base=https://download.docker.com/linux/static/stable/x86_64
    tarball=$dir.tgz
    wget -nv $base/$tarball && tar xaf $tarball
    mv docker $dir
    dir="docker-rootless-extras-$ver"
    tarball=$dir.tgz
    wget -nv $base/$tarball && tar xaf $tarball && rm -rf $dir
    sleep 3 # Allow for network-volume latency
    mv docker-rootless-extras $dir 
}
ok

ok(){
    # Docker CRI-compliant shim : cri-dockerd
    # Usage: kubeadm ... --cri-socket /run/cri-dockerd.sock
    # https://github.com/Mirantis/cri-dockerd
    # https://kubernetes.io/blog/2022/02/17/dockershim-faq/
    # https://github.com/Mirantis/cri-dockerd/releases
    ver='0.3.11'
    dir="cri-dockerd-$ver"
    [[ -d $dir && $(./$dir/cri-dockerd --version 2>&1 |grep $ver) ]] && return 0
    #mkdir -p $dir
    #pushd $dir
    # Download binary
    tarball="$dir.${ARCH}.tgz"
    url=https://github.com/Mirantis/cri-dockerd/releases/download/v${ver}/$tarball
    wget -nv $url && tar -xavf $tarball 
    sleep 3 # Allow for network-volume latency
    mv cri-dockerd $dir 
    # Install cri-dockerd binary
    #sudo mkdir -p /usr/local/bin
    #sudo install -o root -g root -m 0755 cri-dockerd /usr/local/bin/cri-dockerd
    # Download systemd units
    mkdir -p $dir/systemd 
    pushd $dir/systemd
    url="https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd"
    wget -nv $url/cri-docker.service
    wget -nv $url/cri-docker.socket 
    # Configure systemd units for cri-dockerd (service and socket)
    sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' cri-docker.service
    sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' cri-docker.socket
    # sudo cp -p cri-docker.socket /usr/lib/systemd/system/
    # sudo cp -p cri-docker.service /usr/lib/systemd/system/
    # sudo chown root:root /usr/lib/systemd/system/cri-docker.*
    # sudo chmod 0644 /usr/lib/systemd/system/cri-docker.*
    popd 
}
ok

ok(){
    # @ etcd, etcdctl, etcdutl 
    # https://github.com/etcd-io/etcd 
    # https://github.com/etcd-io/etcd/releases/
    ver='v3.5.12'
    dir="etcd-$ver"
    [[ -d $dir && $(./$dir/etcd --version 2>&1 |grep ${ver/v/}) ]] && return 0
    tarball="${dir}-linux-${ARCH}.tar.gz"
    ## Either URL ok
    #GOOGLE_URL=https://storage.googleapis.com/etcd
    GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
    DOWNLOAD_URL="${GITHUB_URL}"
    ## Download and extract
    wget -nv ${DOWNLOAD_URL}/${ver}/$tarball && tar -xaf $tarball
    sleep 3 # Allow for network-volume latency
    mv "${dir}-linux-${ARCH}" $dir
}
ok

ok(){
    # @ Kustomize
    # https://github.com/kubernetes-sigs/kustomize/releases
    ver='5.3.0'
    dir="kustomize-$ver"
    [[ -d $dir && $(./$dir/kustomize version 2>&1 |grep $ver) ]] && return 0
    mkdir -p $dir
    pushd $dir 
    tarball="kustomize_v${ver}_linux_${ARCH}.tar.gz"
    url=https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${ver}/$tarball
    wget -nv $url && tar xvaf $tarball && rm $tarball
    popd
}
ok

ok(){
    # @ Helm 
    # https://helm.sh/docs/intro/install/
    # https://github.com/helm/helm/releases
    ver='v3.14.2'
    dir="helm-$ver" 
    [[ -d $dir && $(./$dir/helm version 2>&1 |grep $ver) ]] && return 0
    helm="helm-${ver}-linux-${ARCH}"
    wget -nv https://get.helm.sh/$helm.tar.gz && tar -xavf $helm.tar.gz # to /usr/local/bin/helm
    sleep 3 # Allow for network-volume latency
    mv linux-${ARCH} $dir 
}
ok

ok(){
    # @ Trivy
    # https://github.com/aquasecurity/trivy/releases 
    ver='0.49.1'
    dir="trivy-$ver"
    [[ -d $dir && $(./$dir/trivy version 2>&1 |grep $ver) ]] && return 0
    mkdir -p $dir
    pushd $dir
    tarball="trivy_${ver}_Linux-64bit.tar.gz"
    url=https://github.com/aquasecurity/trivy/releases/download/v${ver}/$tarball
    wget -nv $url && tar -xvaf $tarball && rm $tarball
    popd
}
ok

ok(){
    # @ yq 
    # https://github.com/mikefarah/yq/releases
    ver='v4.42.1'
    dir="yq-$ver"
    bin='yq_linux_amd64'
    [[ -d $dir && $(./$dir/$bin --version 2>&1 |grep $ver) ]] && return 0
    tarball="${bin}.tar.gz"
    mkdir -p $dir
    pushd $dir
    url="https://github.com/mikefarah/yq/releases/download/${ver}/${tarball}"
    wget -nv $url && tar -xaf $tarball && rm $tarball 
    popd
}
ok

ok(){
    # @ nerdctl : Docker-compatible CLI for containerd 
    # https://github.com/containerd/nerdctl
    # https://github.com/containerd/nerdctl/releases
    # Full : bin/ (binaries), lib/ (systemd configs), libexec/ (cni plugins), share/ (docs)
    ver='1.7.4'
    dir="nerdctl-$ver"
    tarball="nerdctl-full-${ver}-linux-${ARCH}.tar.gz"
    [[ -f $dir/$tarball ]] && return 0
    mkdir -p $dir
    pushd $dir
    base_url=https://github.com/containerd/nerdctl/releases/download/v${ver}
    #target_parent=/usr/local/bin
    wget -nv $base_url/$tarball #&& tar -xaf $tarball 
    popd 
}
ok 

ok(){
    # @ Cilium
    # https://github.com/cilium/cilium
    # https://github.com/cilium/cilium/releases
    # https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#create-the-cluster
    ver='1.15.1' # Chart/App version; CLI reports that, not its version.
    ## CLI (Does NOT report its version, but rather that of the app/image/chart)
    dir="cilium-$ver/cilium-cli"
    [[ -d $dir && $(./$dir/cilium version 2>&1 |grep $ver) ]] && return 0
    mkdir -p $dir
    pushd $dir 
    cli_ver="$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)" # v0.16.0
    tarball="cilium-linux-${ARCH}.tar.gz"
    base='https://github.com/cilium/cilium-cli/releases/download'
    wget -nv $base/${cli_ver}/$tarball && tar -xaf $tarball && rm $tarball
    popd
    ## Chart
    dir="cilium-$ver"
    pushd $dir 
    repo='cilium'
    chart='cilium'
    # Download/save chart, and extract/save its image dependencies (list) and values.yaml
    # https://artifacthub.io/packages/helm/cilium/cilium/
    helm pull --version $ver $repo/$chart && {
        [[ $(type -t hdi) ]] && {
            tar -xaf ${chart}-$ver.tgz && hdi $chart && cp -p $chart/values.yaml . && rm -rf $chart
        } 
    }
    popd
}
ok

ok(){
    # @ Calico : Manifest Method
    ver='3.27.2'
    dir="calico-$ver"
    [[ -f $dir/calico.yaml ]] && return 0
    base=https://raw.githubusercontent.com/projectcalico/calico/v${ver}/manifests 
    # https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises
    mkdir -p $dir 
    wget -nv -O $dir/calico.yaml $base/calico.yaml
    # k apply -f calico.yaml
}
ok 

ok(){
    # @ Ingress NGINX Controller 
    # https://github.com/kubernetes/ingress-nginx/releases
    # https://github.com/kubernetes/ingress-nginx
    # https://kubernetes.github.io/ingress-nginx/deploy/#bare-metal-clusters
    dir='ingress-nginx-controller'
    ## bare-metal-cluster
    ver='1.9.6'
    yaml="ingress-nginx-${ver}-k8s.baremetal.deploy.yaml"
    [[ -f $dir/$yaml ]] && return 0
    echo =====================================
    mkdir -p $dir
    pushd $dir 
    url="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v${ver}/deploy/static/provider/baremetal/deploy.yaml"
    wget -nv -O $yaml $url 
    ## Chart
    # https://github.com/kubernetes/ingress-nginx
    repo='ingress-nginx'
    chart='ingress-nginx'
    ver='4.9.1' # Chart
    #ver='1.9.5' # App
    release='ingress-nginx'
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm pull --version $ver $repo/$chart && {
        [[ $(type -t hdi) ]] && {
            tar -xaf ${chart}-${ver}.tgz && hdi $chart && cp -p $chart/values.yaml . && rm -rf $chart
        } 
    }
}
ok

exit 0



# @ Argo CD 
# https://github.com/argoproj/argo-cd/releases
# https://argo-cd.readthedocs.io/en/stable/getting_started/?_gl=1*1mxdlxv*_ga*MTQwODE5OTE5Ni4xNzEwMTYwNjYz*_ga_5Z1VTPDL73*MTcxMDE2MDY2My4xLjAuMTcxMDE2MDY2Ny4wLjAuMA..
ver='2.10.2'
mkdir -p argocd-$ver
pushd argocd-$ver
## Argo CLI
wget -nv https://github.com/argoproj/argo-cd/releases/download/v${ver}/argocd-linux-amd64
## Argo manifest
#kubectl create namespace argocd
#kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v${ver}/manifests/install.yaml
wget -nv -O argocd.yaml https://raw.githubusercontent.com/argoproj/argo-cd/v${ver}/manifests/install.yaml
# Argo HA manifest
#kubectl create namespace argocd
#kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v${ver}/manifests/ha/install.yaml
wget -nv -O argocd-ha.yaml https://raw.githubusercontent.com/argoproj/argo-cd/v${ver}/manifests/ha/install.yaml
popd 


# @ Istio : Image dependencies are effectively hidden, eg, "istio/proxyv2" is a bogus image
# https://istio.io/latest/docs/setup/getting-started/
# https://github.com/istio/istio/releases/
ver='1.20.3' # App / Chart (same)
dir="istio-$ver"
mkdir -p $dir
push $dir 
## istioctl method
mkdir -p istioctl-method
pushd istioctl-method
tarball="${dir}-linux-${ARCH}.tar.gz"
wget -nv https://github.com/istio/istio/releases/download/$ver/$tarball
tar xaf $tarball
popd 
## Helm method 
# https://artifacthub.io/packages/helm/istio-official/istiod
mkdir -p helm-method
pushd helm-method
repo='istio-official'
chart='istiod' 
helm pull --version $ver $repo/$chart    
helm pull --version $ver $repo/$chart && {
        [[ $(type -t hdi) ]] && {
            tar -xaf ${chart}-$ver.tgz && hdi $chart && cp -p $chart/values.yaml . && rm -rf $chart
        } 
    }
popd
popd 


# @ Vault https://hub.docker.com/r/hashicorp/vault
## vault-secrets-operator : https://github.com/hashicorp/vault-secrets-operator
#docker pull hashicorp/vault:1.15.6
# https://artifacthub.io/packages/helm/hashicorp/vault
# 1.15.2 @ 0.27.0
ver='1.15.2'
mkdir -p vault-$ver
pushd vault-$ver
helm repo add hashicorp https://helm.releases.hashicorp.com
helm pull hashicorp/vault --version 0.27.0
popd 

# @ Metrics Server 
# https://artifacthub.io/packages/helm/metrics-server/metrics-server
ver='0.7.0' # App version 
mkdir -p metrics-server-$ver
pushd metrics-server-$ver
ver='3.12.0' # Chart version 
helm pull metrics-server/metrics-server --version $ver 
#tar -xaf metrics-server-$ver.tgz
#find metrics-server -type f -iname '*.yaml' -exec cat {} \; |grep -A1 repository
popd 

# @ fluent-operator : Fluentd + Fluent Bit
# https://github.com/fluent/fluent-operator
# https://artifacthub.io/packages/helm/fluent/fluent-operator
ver='2.7.0'
repo='fluent'
chart='fluent-operator'
mkdir $chart-$ver 
pushd $chart-$ver 
helm repo add $repo https://fluent.github.io/helm-charts
helm pull --version=$ver $repo/$chart
wget -nv https://github.com/fluent/fluent-operator/archive/refs/heads/master.zip
popd 

# StorageClass

# @ nfs-client : nfs-subdir-external-provisioner
# https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/releases
# https://artifacthub.io/packages/helm/nfs-subdir-external-provisioner/nfs-subdir-external-provisioner
ver='4.0.18' # Chart : image tag: 4.0.2
repo='nfs-subdir-external-provisioner'
chart='nfs-subdir-external-provisioner'
mkdir -p nfs-client-$ver 
pushd nfs-client-$ver 
#release='nfs-client'
helm pull --version $ver $repo/$chart
popd 

# @ longhorn : local-storage : rancher/local-path-provisioner
# https://github.com/rancher/local-path-provisioner
# https://artifacthub.io/packages/helm/longhorn/longhorn
repo='longhorn'
chart='longhorn'
mkdir -p $repo
pushd $repo 
ver='1.6.0' # App + Chart
mkdir -p helm-method-$ver
push helm-method-$ver
## Helm method
#release='nfs-client'
helm repo add longhorn https://charts.longhorn.io
helm pull --version $ver $repo/$chart 
# INSTALL TO NAMESPACE : --namespace longhorn-system
popd 
## kubectl method
ver='1.5.3'
mkdir -p kubectl-method-$ver
pushd kubectl-method-$ver
# https://longhorn.io/docs/1.5.3/deploy/install/install-with-kubectl/
yaml=longhorn.yaml
url=https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/$yaml
wget -nv $url
popd 


exit 0
######

#######################################################################
# Extract all images of Helm charts (*.tgz) and values.yaml under PWD:
#######################################################################

images(){
    [[ -f $1 ]] && cat $1 |grep -e repository: -e registry: -e image: -e tag:
}
export -f images 

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

# Result (edited)

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
