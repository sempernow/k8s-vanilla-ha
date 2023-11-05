#!/usr/bin/env bash
#
#  Cluster TEARDOWN : Execute at each node
#

FLAG_DELETE_IMAGES=$1
[[ "$FLAG_DELETE_IMAGES" != 'FLAG_DELETE_IMAGES' ]] \
    && unset FLAG_DELETE_IMAGES

psk()
{
    k8s='
            containerd
            dockerd
            etcd
            kubelet
            kube-apiserver
            kube-controller-manager
            kube-scheduler
            kube-proxy
        ';
    function _ps ()
    {
        [[ -n "$1" ]] || exit 1;
        echo @ $1;
        ps aux |grep --color -- "$1 " |tr ' ' '\n' |grep --color -- -- \
            |grep --color -v color |grep --color -v grep
    };
    export -f _ps;
    [[ -n "$1" ]] && _ps $1 || {
        echo $k8s | xargs -n 1 /bin/bash -c '_ps "$@"' _
    }
}

echo '=== @ Teardown'

[[ $(kubectl get node 2>/dev/null) ]] && { 

    podNetwork=calico.yaml

    isMasterNode=false
    [[ $(kubectl get node |grep control-plane |grep $(hostname)) ]] && isMasterNode=true

    [[ $isMasterNode ]] && {
        
        # Cordon and drain worker nodes
        kubectl get node |grep -v control-plane |grep -v NAME |xargs -L 1 /bin/bash -c '
            sudo kubectl cordon $1
            sudo kubectl drain $1 --ignore-daemonsets=true --force=true --grace-period=10 --skip-wait-for-delete-timeout=15
        ' _

        # Drain control nodes
        kubectl get node |grep control-plane |grep -v NAME |xargs -L 1 /bin/bash -c '
            sudo kubectl drain $1 --ignore-daemonsets=true --force=true --grace-period=10 --skip-wait-for-delete-timeout=15
        ' _

        # Delete all Deployment objects
        kubectl get deploy -A |grep -v NAME |xargs -L 1 /bin/bash -c '
            kubectl -n $1 delete deploy $2
        ' _

        # Delete all StatefulSet objects
        kubectl get sts -A |grep -v NAME |xargs -L 1 /bin/bash -c '
            kubectl -n $1 delete deploy $2
        ' _

        # Uninstall all Helm charts
        helm list -a |grep -v NAME |xargs -L 1 /bin/bash -c '
            helm -n $1 uninstall $2
        ' _

        # Delete Pod network/addon/CRDs
        [[ -r $podNetwork ]] && kubectl delete -f $podNetwork
    }
}

# Destroy the K8s cluster (if it exists)

kubelet="$(ps aux |grep kubelet |grep -v grep)"
apiserver="$(ps aux |grep kube-apiserver |grep -v grep)"
manifests="$(ls -l /etc/kubernetes/manifests/ |wc -l)"
pki="$(ls -l /etc/kubernetes/pki/ |wc -l)"
[[ "$kubelet" || $apiserver || $manifests != "1" || "$pki" != "1" ]] \
    && sudo kubeadm reset --force \
    || echo 'This node has no cluster to reset.'

# Clean up any residual Pods or containers

pods(){ echo "$(sudo crictl pods |grep -v STATE |awk '{print $1}')"; }
ps(){ echo "$(sudo crictl ps |grep -v STATE |awk '{print $1}')"; }

# Remove all remaining containers on this node
ps |xargs -IX /bin/bash -c '
        sudo crictl stop $1 && sudo crictl rm $1
    ' _ X

# Remove all remaining pods on this node
pods |xargs -IX /bin/bash -c '
        sudo crictl stopp $1 && sudo crictl rmp $1
    ' _ X

# If any Pods or containers remain, then remove containerd cache 

[[ $(pods) ]] && echo "*** FAIL @ crictl : Pods remain"
[[ $(ps) ]] && echo "*** FAIL @ crictl : Containers remain"
[[ $FLAG_DELETE_IMAGES ]] && {
    sudo systemctl disable --now containerd.service
    sudo rm -rf /var/lib/containerd
    sudo mkdir -p /var/lib/containerd
    sudo systemctl enable --now containerd.service
}

# Clear CNI cruft
sudo rm -rf /var/lib/cni/*
sudo rm -rf /etc/cni/*

# Delete client config
sudo rm -rf $HOME/.kube/*

#sudo systemctl enable --now containerd.service

echo '=== @ Verify'

manifests="$(ls -hl /etc/kubernetes/manifests |grep -v total)"
[[ $manifests ]] && printf "*** FAIL @ kubeadm reset : Manifests remain at /etc/kubernetes/manifests/: \n%s\n\n" "$manifests"

psk
# systemctl status kubelet.service 
#... "Failed" because '/var/lib/kubelet/config.yaml' does not exist.
sudo crictl images
