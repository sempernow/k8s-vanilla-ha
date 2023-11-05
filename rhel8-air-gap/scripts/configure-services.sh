#!/usr/bin/env bash
###############################################################################
# Configure systemd services
# - Run this script after all (RPMs and binaries) installed. 
# - Idempotent. 
# - Order matters.
###############################################################################

is_containerd(){ 
    [[ "$(systemctl is-active containerd.service)" == 'active' ]] && echo 'yes' || echo ''
}
unset flag

gid(){ echo "$(getent group $1 |cut -d':' -f3)"; }
export -f gid 

# @ crictl config : allow members of containerd group to run CRI tools sans sudo 
[[ $(is_containerd) ]] && { 
    ## Create containerd group:
    [[ $(getent group containerd) ]] || {
        echo '=== Create containerd group'
        sudo groupadd containerd
    }
    [[ $(getent group containerd) ]] && {
        ## Change containerd.sock group
        socket=/var/run/containerd/containerd.sock
        sudo chown :containerd $socket && ls -l $socket
        [[ $(ls -ln $socket |grep " $(gid containerd) ") ]] || echo "=== FAIL @ cri-tools config : socket group UNCHANGED"
    } || echo '=== FAIL @ cri-tools config : group "containerd" NOT EXIST'
} || echo "=== FAIL @ cri-tools config : containerd.service is REQUIRED"



# @ containerd.service
[[ $(is_containerd) ]] || {
    echo '=== @ containerd.service'
    sudo systemctl enable --now containerd.service
    systemctl status containerd.service
    flag=1
}

# @ docker.service
export registry="http://${CNCF_REGISTRY_HOST}:5000"

[[ -f /etc/docker/daemon.json ]] || flag=1
[[ -f /etc/docker/daemon.json ]] || cat <<-EOH |sudo tee /etc/docker/daemon.json
{
    "proxies": {
        "http-proxy": "http://contractorproxyeast.northgrum.com:80",
        "https-proxy": "http://contractorproxyeast.northgrum.com:80",
        "no-proxy": "localhost,127.0.0.1,192.168.0.0/16,172.16.0.0/16,.entds.ngisn.com,.edn.entds.ngisn.com,.dilmgmt.c4isrt.com,.dil.es.northgrum.com,.ms.northgrum.com,.es.northgrum.com,.northgrum.com"
    },
    "insecure-registries": ["127.0.0.0/8","$registry"]
}
EOH

[[ "$(systemctl is-active docker.service)" == 'active' ]] || {
    flag=1
    [[ $(is_containerd) ]] && {
        echo '=== @ docker.service'
        sudo systemctl daemon-reload
        sudo systemctl enable --now docker.service
        systemctl status docker.service
    } || echo '=== FAIL @ docker.service enable/start : REQUIREs containerd.service'
}

# @ kubelet.service : Must be "active" || "activating"
[[ $(echo "$(systemctl status kubelet.service)" |grep Active |grep ' activ') ]] || {
    [[ $(type -t etcd) ]] && {
        [[ $(is_containerd) ]] && {
            echo '=== @ kubelet.service'
            sudo systemctl enable --now kubelet.service
            systemctl status kubelet.service
        } || echo '=== FAIL @ kubelet.service enable/start : REQUIREs containerd.service'
    } || echo '=== FAIL @ kubelet.service enable/start : REQUIREs etcd install'
}

gid(){ echo "$(getent group $1 |cut -d':' -f3)"; }
export -f gid 

# @ crictl config : allow members of containerd group to run CRI tools sans sudo 
## THIS IS FAILing to achieve desired result : /run/containerd/containerd.sock under systemd resets on start
[[ $(is_containerd) ]] && { 
    ## Create containerd group:
    [[ $(getent group containerd) ]] || {
        echo '=== Create containerd group'
        sudo groupadd containerd
    }
    [[ $(getent group containerd) ]] && {
        ## Change containerd.sock group
        socket=/var/run/containerd/containerd.sock
        sudo chown :containerd $socket && ls -l $socket
        [[ $(ls -ln $socket |grep " $(gid containerd) ") ]] || echo "=== FAIL @ cri-tools config : socket group UNCHANGED"
    } || echo '=== FAIL @ cri-tools config : group "containerd" NOT EXIST'
} || echo "=== FAIL @ cri-tools config : containerd.service is REQUIRED"


[[ $(type -t docker) ]] && {
    ## Create docker group:
    [[ $(gid docker) ]] || {
        echo '=== Create docker group'
        sudo groupadd docker
    }
    [[ $(gid docker) ]] || echo '=== FAIL @ docker config : group "docker" NOT EXIST'
}
