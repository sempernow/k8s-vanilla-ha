#!/usr/bin/env bash
#
#  Cluster TEARDOWN : Execute at each node
#
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
        ps aux | grep --color -- $1 | tr ' ' '\n' | grep --color -- -- | grep --color -v color | grep --color -v grep
    };
    export -f _ps;
    [[ -n "$1" ]] && _ps $1 || {
        echo $k8s | xargs -n 1 /bin/bash -c '_ps "$@"' _
    }
}

[[ $(kubectl get node 2>/dev/null) ]] && { 

    podNetwork=calico.yaml

    isMasterNode=false
    [[ $(kubectl get node |grep control-plane |grep $(hostname)) ]] && isMasterNode=true

    echo '=== @ Teardown'

    [[ $isMasterNode ]] && {
        ## Cordon and drain worker nodes
        kubectl get node |grep -v control-plane |grep -v NAME |xargs -l /bin/bash -c '
            sudo kubectl cordon $1
            sudo kubectl drain $1 --ignore-daemonsets=true --force=true --grace-period=10 --skip-wait-for-delete-timeout=15 --timeout=20
        ' _

        ## Delete all Deployment objects
        kubectl get deploy -A |grep -v NAME |xargs -l /bin/bash -c '
            kubectl -n $1 delete deploy $2
        ' _

        ## Delete all StatefulSet objects
        kubectl get sts -A |grep -v NAME |xargs -l /bin/bash -c '
            kubectl -n $1 delete deploy $2
        ' _

        ## Delete all Helm charts
        helm list -a |grep -v NAME |xargs -l /bin/bash -c '
            helm -n $1 uninstall $2
        ' _

        ## Delete Pod network/addon/CRDs
        [[ -r $podNetwork ]] && kubectl delete -f $podNetwork
    }
}

sudo kubeadm reset --force
#sudo systemctl disable --now containerd.service
#sudo rm -rf /var/lib/containerd/*
sudo rm -rf ~/.kube/*
sudo rm -rf /var/lib/cni/*
sudo rm -rf /etc/cni/*
#sudo systemctl enable --now containerd.service

echo '=== @ Verify'

[[ $(kubectl get node 2>/dev/null) ]] && kubectl get pod -A
ls -hl /etc/kubernetes/manifests
psk
