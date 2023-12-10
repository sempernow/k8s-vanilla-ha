#!/usr/bin/env bash
# Install all 3 binaries of an etcd release:
# etcd, etcdctl, etcdutl : https://github.com/etcd-io/etcd 
# Releases : https://github.com/etcd-io/etcd/releases/

# Prep

ver=v3.5.10
arch=amd64
tarball="etcd-${ver}-linux-${arch}.tar.gz"

## Either URL ok
GOOGLE_URL=https://storage.googleapis.com/etcd
GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
DOWNLOAD_URL="${GITHUB_URL}"

tmpdir=/tmp/etcd-io

rm -rf $tmpdir
mkdir -p $tmpdir

## Download and extract to $tmpdir
wget -nv ${DOWNLOAD_URL}/${ver}/$tarball -O /tmp/$tarball \
    && tar -xzv -C $tmpdir --strip-components=1 -f /tmp/$tarball

# Install binaries from $tmpdir into /usr/bin/
printf "%s\n" etcd etcdctl etcdutl |xargs -IX /bin/bash -c \
    '
        [[ -f $0/$1 ]] && sudo mv $0/$1 /usr/bin/$1 \
            && sudo chown root:root /usr/bin/$1
    ' $tmpdir X

## Verify
echo '=== etcd + tools are installed:'
ls -Ahl /usr/bin/etc*
etcd --version
etcdctl version
etcdutl version

# Test : How-to
echo '
    Test etcd (standalone, per-node) using: `ssh $vm /bin/bash -s < etcd-test.sh`
'

