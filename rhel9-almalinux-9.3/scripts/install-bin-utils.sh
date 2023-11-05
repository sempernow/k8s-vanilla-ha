#!/usr/bin/env bash
###############################################################################
# Install binaries 
###############################################################################

# Install yq (jq for yaml)
# https://github.com/mikefarah/yq/releases
VERSION='4.40.5'
BINARY=yq_linux_amd64
url="https://github.com/mikefarah/yq/releases/download/v${VERSION}/${BINARY}.tar.gz"

[[ $(yq --version |grep $VERSION) ]] || {
    wget --quiet $url -O - |tar xz \
        && sudo mv ${BINARY} /usr/bin/yq \
        && sudo chown root:root /usr/bin/yq
}
yq --version
