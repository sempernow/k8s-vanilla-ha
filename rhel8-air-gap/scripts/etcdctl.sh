#!/usr/bin/env bash
# etcdctl wrapper

export ETCDCTL_API=3 
sudo /usr/local/bin/etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    "$@" 


exit 0
######