#!/usr/bin/env bash
# https://helm.sh/docs/intro/install/

arch=amd64
ver='3.13.3'

echo '=== Download/Install : helm'
[[ $(helm version 2>&1 |grep $ver) ]] && {
    helm version
} || {
    tarball="helm-v${ver}-linux-${arch}.tar.gz"
    wget -nv https://get.helm.sh/$tarball \
        && tar -xavf $tarball \
        && sudo mv linux-${arch}/helm /usr/local/bin/helm
}
[[ $(helm version 2>&1 |grep $ver) ]] || {
    echo '=== FAIL @ Helm install'
}
