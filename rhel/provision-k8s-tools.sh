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
[[ $1 ]] && {
    ssh_configured_machines="$@"
} || {
    echo "REQUIREs the list of ssh-configured machines to provision." 
    echo "USAGE : ${0##*/} VM1 VM2 ..." 
    exit
}

_ssh(){ 
    mode=$1;shift
    for vm in $ssh_configured_machines
    do
        echo "=== @ $vm : $1 $2 $3 ..."
        [[ $mode == '-s' ]] && ssh $vm "/bin/bash -s" < "$@"
        [[ $mode == '-c' ]] && ssh $vm "/bin/bash -c" "$@"
        [[ $mode == '-x' ]] && ssh $vm "$@"
    done 
}

# Prep hosts 
_ssh -s 'prep-env.sh'
_ssh -s 'ports-k8s.sh'
_ssh -s 'ports-istio.sh'
_ssh -s 'ports-calico.sh'
_ssh -x 'sudo firewall-cmd --reload'

# Install tc (for kubeadm), and some rudimentary tools lacking in many RHEL-type distros.
_ssh -x 'sudo dnf -y install iproute-tc bash-completion bind-utils tar wget git jq vim tree'

# Install yq
## https://github.com/mikefarah/yq/releases
VERSION=v4.35.2
BINARY=yq_linux_amd64
url="https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz"

_ssh -x "
    wget $url -O - |tar xz \
        && sudo mv ${BINARY} /usr/bin/yq \
        && sudo chown root:root /usr/bin/yq
        yq --version
"

# Install containerd through Docker CE install.
_ssh -s 'install-containerd-docker-rhel.sh'

# Configure containerd to use systemd driver instead of its default (cgroupfs driver).
_ssh -x "
    sudo systemctl --now disable containerd.service
    echo '$(<config-cka.toml)' |sudo tee /etc/containerd/config.toml
    sudo systemctl --now enable containerd.service
"

# Configure Docker server to start on boot
_ssh -x "
    sudo systemctl --now enable docker.service
    sudo systemctl status docker.service
"

# Install kubernetes tools
_ssh -s 'install-k8s-tools-rhel.sh'

# Report/Info
echo "=== DONE : PROVISIONED nodes : $ssh_configured_machines"
echo '
    After initializing the first control node using `sudo kubeadm init`, 
    note the distinct instructions for "join" statement (control v. worker node).
    Before adding any other nodes, install Calico or other CNI-compliant plugin 
    to setup the Pod Network. Then, at every other node, 
    use the `sudo kubeadm join ...` statements
    per node type (noted upon init) to join the cluster.
'
