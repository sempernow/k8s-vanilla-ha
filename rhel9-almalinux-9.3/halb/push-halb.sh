#!/usr/bin/env bash
#################################################
# Highly Available (HA) Load Balancer (LB)
#
# Push HA-LB configuration to nodes. 
#
# See Makefile recipes : lbconf, lbpush
#################################################

# This script requires its PWD to be its own directory.
cd "${BASH_SOURCE%/*}"

[[ $GITOPS_NODES_MASTER ]] || { echo '=== Environment is NOT CONFIGURED';exit; } 

printf "%s\n" $GITOPS_NODES_MASTER |xargs -IX /bin/bash -c '
    echo "=== @ $1"
    scp keepalived-${1}.local.conf ${1}:keepalived.conf
    scp keepalived-check_apiserver.sh ${1}:keepalived-check_apiserver.sh
    scp haproxy.cfg ${1}:haproxy.cfg
    ssh $1 "
        sudo cp keepalived.conf /etc/keepalived/keepalived.conf
        sudo chmod 0644 /etc/keepalived/keepalived.conf
        sudo cp keepalived-check_apiserver.sh /etc/keepalived/check_apiserver.sh
        sudo chmod 0755 /etc/keepalived/check_apiserver.sh
        sudo cp haproxy.cfg /etc/haproxy/haproxy.cfg
        sudo chmod 0644 /etc/haproxy/haproxy.cfg
        sudo systemctl restart haproxy.service
        sudo systemctl restart keepalived.service
    "
' _ X
