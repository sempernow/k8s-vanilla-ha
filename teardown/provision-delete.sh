#!/usr/bin/env bash
# Delete cluster

#>>>  WIP  <<<

K8S_WORKER_NODES='a3'
K8S_MASTER_NODES='a0 a1'

master=$(echo $K8S_MASTER_NODES |cut -d' ' -f1)

echo '=== Delete all Helm charts'
ssh $master /bin/bash -s < delete-charts.sh

# Drain all nodes
opts='--delete-emptydir-data --force --ignore-daemonsets'
#=> E1029 ... couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp 192.168.65.4:8080: i/o timeout
echo "=== Drain worker nodes : $K8S_WORKER_NODES"
[[ "$K8S_WORKER_NODES" ]] && {
    ssh $master printf '%s\\n' "$K8S_WORKER_NODES" \
        |xargs -I{} kubectl drain {}.local $opts
}
echo "=== Drain master nodes : $K8S_MASTER_NODES"
[[ "$K8S_MASTER_NODES" ]] && {
    ssh $master printf '%s\\n' "$K8S_MASTER_NODES" \
        |xargs -I{} kubectl drain {}.local $opts
}

echo "=== Delete K8s resources"
ssh $master /bin/bash -s < delete-resources.sh

# Delete all nodes
echo "=== Delete worker nodes : $K8S_WORKER_NODES"
[[ "$K8S_WORKER_NODES" ]] && {
    ssh $master printf "%s\\n" $K8S_WORKER_NODES \
        |xargs -I{} kubectl delete node {}.local 
}
echo "=== Delete master nodes : $K8S_MASTER_NODES"
[[ "$K8S_MASTER_NODES" ]] && {
    ssh $master printf "%s\\n" $K8S_MASTER_NODES \
        |xargs -I{} kubectl delete node {}.local
}

echo '=== crictl stop : All containers'
ssh $master /bin/bash -s < crictl-stop.sh

# Reset K8s client and server at every node
echo '=== Reset K8s client and server at every node'
printf "%s\n" $K8S_WORKER_NODES $K8S_MASTER_NODES |xargs -IX ssh X '
    rm -rf $HOME/.kube/*
    sudo kubeadm reset --force
    sudo systemctl disable --now containerd.service
    sudo rm -rf /var/lib/containerd/*
    sudo rm -rf ~/.kube/*
    sudo rm -rf /etc/cni/net.d/*
    sudo systemctl enable --now containerd.service
'
# sudo rm -rf /var/lib/containerd/*
