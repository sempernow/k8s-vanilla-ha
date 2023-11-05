#!/usr/bin/env bash
###############################################################################
# Working from an administrative machine, 
# provision a list of targeted machines with all that is necessary 
# to initialize a Vanilla Kubernetes cluster using kubadm.
#
# Client-machine requirements:
# - SSH params for configured for target machine(s) 
#   - See ~/.ssh/config
#
# Target-machine requirements:
# - OS: AlmaLinux 8.
# - CPUs: 2+ if control node, else 1+.
# - Memory: 2048GB+.
# - sudo sans password prompt:
#    `echo "$USER ALL=(ALL) NOPASSWD:ALL" |sudo tee /etc/sudoers.d/$USER`
#
# ARGs: <list of ssh-configured machines>
###############################################################################

#####################
#>>>  DEPRICATED  <<<
#####################

# This script requires its PWD to be its own directory.
cd "${BASH_SOURCE%/*}"

[[ $1 ]] && {
    ssh_configured_hosts="$@"
    [[ $ssh_configured_hosts ]] || ssh_configured_hosts="${ANSIBASH_TARGET_LIST}"
}
[[ $ssh_configured_hosts ]] || {
    echo "REQUIREs the list of ssh-configured machines to provision." 
    echo "USAGE : ${0##*/} VM1 VM2 ..." 
    exit
}

_ssh(){ 
    # mode=$1;shift
    # for vm in $ssh_configured_hosts
    # do
    #     echo "=== @ $vm : $1 $2 $3 ..."
    #     [[ $mode == '-s' ]] && ssh $vm "/bin/bash -s" < "$@"
    #     [[ $mode == '-c' ]] && ssh $vm "/bin/bash -c" "$@"
    #     [[ $mode == '-x' ]] && ssh $vm "$@"
    # done 
    ANSIBASH_TARGET_LIST="$ssh_configured_hosts"
    ansibash "$@"
}

echo '@ Prep hosts'
_ssh -s install-rpms.sh
_ssh -s prep-env.sh
_ssh -s firewalld-k8s.sh
_ssh -s firewalld-istio.sh
_ssh -s firewalld-calico.sh
_ssh -x 'sudo firewall-cmd --reload'


# Install containerd through Docker CE install.
_ssh -s install-containerd-docker-rhel.sh

# Mods after install of RPM pkgs
_ssh -s post-env.sh

# Configure containerd : See /etc/containerd/config.toml
## Sets cgroup driver to systemd instead of its default (cgroupfs).
_ssh -x "
    echo '$(<config-containerd.toml)' |sudo tee /etc/containerd/config.toml
    sudo systemctl daemon-reload
    sudo systemctl --now enable containerd.service
    systemctl status containerd.service
"

# Configure Docker server to start on boot
_ssh -x "
    sudo systemctl --now enable docker.service
    [[ $(type -t cri-dockerd) ]] && {
        sudo systemctl enable --now cri-docker.socket
        sudo systemctl enable --now cri-docker.service
    }
"

# Install kubernetes tools
_ssh -s install-k8s-tools-rhel.sh

# Report/Info
echo "=== DONE : PROVISIONED nodes : $ssh_configured_hosts"
echo '
    After initializing the first control node using `sudo kubeadm init`, 
    note the distinct instructions for "join" statement (control v. worker node).
    Before adding any other nodes, install Calico or other CNI-compliant plugin 
    to setup the Pod Network. Then, at every other node, 
    use the `sudo kubeadm join ...` statements
    per node type (noted upon init) to join the cluster.
'
