#!/usr/bin/env bash
# https://helm.sh/docs/intro/install/

ARCH=${PRJ_ARCH:-amd64}
ver='3.13.3' # Release info is a well kept secret of Helm project!

echo '=== Download/Install : helm'
[[ $(helm version 2>&1 |grep $ver) ]] && {
    helm version
} || {
    tarball="helm-v${ver}-linux-${ARCH}.tar.gz"
    wget -nv https://get.helm.sh/$tarball \
        && tar -xavf $tarball \
        && sudo mv linux-${ARCH}/helm /usr/local/bin/helm
}
[[ $(helm version 2>&1 |grep $ver) ]] || {
    echo '=== FAIL @ Helm install'
}
