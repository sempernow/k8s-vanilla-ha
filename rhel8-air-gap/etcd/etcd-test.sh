#!/usr/bin/env bash
# Test etcd install

## Don't disturb etcd if already running; may be member at K8s control plane.
[[ $(ps aux |grep etcd |grep -v grep |awk '{print $2}') ]] && {
    echo '=== NO TEST : etcd is ALREADY RUNNING'
    exit 99
}

## Server/Client (etcd/etcdctl) USAGE:
echo '=== Start etcd as background process'
nohup etcd > etcd.log 2>&1 &

echo '=== Write : put foo bar'
etcdctl --endpoints=localhost:2379 put foo bar

echo '=== Read : get foo'
etcdctl --endpoints=localhost:2379 get foo

echo '=== Stop etcd server'
kill $(ps aux |grep etcd |grep Sl |grep -v grep |awk '{print $2}') \
    || kill $(ps aux |grep etcd |grep Ssl |grep -v grep |awk '{print $2}')

exit 0
######