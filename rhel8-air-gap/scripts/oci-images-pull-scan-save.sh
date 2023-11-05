#!/usr/bin/env bash
#################################
# Pull, scan, save OCI images
# 
# ARGs: <images-list file>
#################################
ifname(){
    # Make fname given registry:port/repo/name:tag <> registry_port.repo.name_tag
    fname=$1
    fname=${fname////.}
    echo ${fname//:/_}
}
export -f ifname 

[[ $(type -t trivy) ]] || { 
    echo '  Requires trivy'
    exit 0
}
[[ $1 ]] || {
    echo "  USAGE: ${BASH_SOURCE##*/} IMAGES_LIST_FILE"
    exit 0
}

list="$1"
export folder="oci-images-$list"
mkdir -p $folder

## Update its CVE database
trivy image --download-db-only  

## Pull, Scan and Save
cat $list |xargs -I{} /bin/bash -c '
    docker pull $1
    trivy image $1 |& tee $folder/$(ifname $1).scan.log
    [[ -f $(ifname $1).tar.gz ]] || {
        docker save $1 |gzip -c > $folder/$(ifname $1).tar.gz
    }
' _ {}

exit 0

############################################
# Can use this if docker cache is EMPTY:
############################################

dit(){ docker image ls --format "table {{.ID}}\t{{.Repository}}:{{.Tag}}\t{{.Size}}"; }
export -f dit 

## Pull 
list="$@"
cat $list |xargs -I{} docker pull {}

## Scan
## Update its CVE database
trivy image --download-db-only 

## Scan all images in cache
dit |awk '{print $2}' |xargs -I{} /bin/bash -c '
    trivy image $1 |& tee $(ifname $1).scan.log
' _ {}

## Save
cat $list |xargs -I{} /bin/bash -c '
    [[ -f $(ifname $1).tar.gz ]] || {
        docker save $1 |gzip -c > $(ifname $1).tar.gz
    }
' _ {}

exit
###

############################
## Lists : HowTo build them
############################

# Single image
# Pull
img='redis:7.2.3-alpine3.18'
docker pull $img
# Scan
trivy image --download-db-only  # Update its CVE database
trivy image $img |tee $(ifname $img).scan.log
#tar=${img////.}
#[[ -f ${tar/:/_}.tar ]] || docker save $img -o ${tar/:/_}.tar
# Save +Gzip
[[ -f $(ifname $img).tar.gz ]] || {
    docker save $img |gzip -c > $(ifname $img).tar.gz
}


# Gzip : Can load directly using `docker load -i $img`
gzip $img # .tar => .tar.gz 

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

# Gzip (to .tar.gz) : can load directly using `docker load -i img-x.tar.gz`
find . -type f -iname '*.tar' -exec gzip {} \;

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


## Other methods of extracting images (from all Helm charts under PWD):

find . -type f -iname 'values.yaml' -exec /bin/bash -c 'images $1' _ {} \;

find . -type f -iname '*.tgz' -exec /bin/bash -c '
    images="$(helm template $1 |yq .spec.template.spec.containers[].image |sort -u)"
    [[ "$images" ]] && echo "$images" |grep -v -- --- 
' _ {} \; 2>&1 |grep -v ' ' |sort -u



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
