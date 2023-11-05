#!/usr/bin/env bash
# - Install containerd as the CRI runtime for Kubernetes. 
# - Install Docker CE server and client.
# REF:
#   https://kubernetes.io/docs/setup/production-environment/
#   https://github.com/containerd/containerd/releases

[[ $(type -t dnf) ]] || { echo '=== REQUIREs dnf Package Manager'; exit 11; } 

# CRI Runtime : containerd
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd

echo '@ CRI Runtime : Configure network prerequisites'
## br_netfilter enables transparent masquerading and facilitates Virtual Extensible LAN (VxLAN) traffic for communication between Kubernetes pods across the cluster.
cat << EOF |sudo tee /etc/modules-load.d/k8s-containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

## Set iptables bridging 
cat << EOF |sudo tee /etc/sysctl.d/k8s-containerd.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

## Apply sysctl params without reboot
sudo sysctl --system

echo '@ CRI Runtime : Verify network prerequisites'

## Verify network prerequisites
[[ $(lsmod |grep br_netfilter) ]] \
    && echo '=== OKAY : br_netfilter module' \
    || echo '=== FAIL : br_netfilter module'
[[ $(lsmod |grep overlay) ]] \
    && echo '=== OKAY : overlay module' \
    || echo '=== FAIL : overlay module'
# Show settings (k = v)
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

echo '@ Docker CE + containerd and dependencies'

the_hard_way(){
    # Containerd
    cri_version='1.7.8'
    [[ $(arch) = aarch64 ]] && cri_arch=arm64
    [[ $(arch) = x86_64  ]] && cri_arch=amd64
    [[ $cri_arch ]] || { echo '=== FAIL @ containerd install';exit 99; }

    ## Install containerd
    release="containerd-${cri_version}-linux-${cri_arch}"
    wget ${release}.tar.gz
    tar -C /usr/local -xzvf ${release}.tar.gz

    ## Install containerd.service unit file
    wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service \
        |sudo tee /usr/local/lib/systemd/system/containerd.service

    ## Enable containerd
    sudo systemctl daemon-reload
    sudo systemctl enable --now containerd

    # runc
    ## Add EPEL : Extra Packages for Enterprise Linux
    echo "=== Adding EPEL repo"
    sudo dnf install -y epel-release
    sudo dnf -y upgrade
    ## Verify EPEL repo added
    rpm -q epel-release 

    ## Install runc 1.1.9
    ## REFs:
    ### https://github.com/opencontainers/runc/releases/tag/v1.1.9
    ### https://rpmfind.net/linux/rpm2html/search.php?query=runc
    pkg='runc-1.1.9-1.module_el8+643+8db347f4.x86_64.rpm'
    wget https://rpmfind.net/linux/centos/8-stream/AppStream/x86_64/os/Packages/$pkg
    sudo dnf -y install --nogpgcheck $pkg
    which runc # Should be @ /usr/local/sbin/runc
}

the_easy_way(){
    # Piggyback on a Docker install
    # https://docs.docker.com/engine/install/centos/
    
    # Prep
    echo '@ Docker prep : Install yum-utils'
    sudo yum -y install yum-utils
    url='https://download.docker.com/linux/centos/docker-ce.repo'
    #sudo yum-config-manager --add-repo $url # command not exist
    sudo dnf -y config-manager --add-repo $url
    
    sudo yum -y update

    # Install Docker-CE server (dockerd), client (docker), tools and dependencies
    echo '@ Docker + CRI Runtime (containerd) : Install'
    sudo yum -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # ERROR:
        # Running scriptlet: container-selinux-2:2.205.0-2.module_el8.8.0+3615+   17/20
        # Symbol not inside parenthesis at line 1 of /var/lib/selinux/targeted/tmp/modules/100/postgresql/cil
        # Failed to allocate memory

    # Install cri-tools : crictl + critest
    [[ $(type -t crictl) ]] || {
        # https://github.com/kubernetes-sigs/cri-tools
        # https://github.com/kubernetes-sigs/cri-tools/releases/
        ver="v1.28.0" 
        base_url="https://github.com/kubernetes-sigs/cri-tools/releases/download/$ver"

        echo '@ cri-tools : Download and Install'
        echo '=== crictl'
        # @ crictl binary : Download and install
        wget --quiet $base_url/crictl-$ver-linux-amd64.tar.gz \
            && sudo tar zxvf crictl-$ver-linux-amd64.tar.gz -C /usr/local/bin \
            && rm -f crictl-$ver-linux-amd64.tar.gz

        echo '=== critest'
        # @ critest binary : Download and install
        wget --quiet $base_url/critest-$ver-linux-amd64.tar.gz \
            && sudo tar zxvf critest-$ver-linux-amd64.tar.gz -C /usr/local/bin \
            && rm -f critest-$ver-linux-amd64.tar.gz
    }
    [[ $(type -t crictl) ]] && {

        echo '@ cri-tools : Configure'
        # CRI tools require sudo to run, yet they are not in sudo PATH, so create soft link
        sudo ln -s /usr/local/bin/crictl  /usr/sbin/crictl
        sudo ln -s /usr/local/bin/critest /usr/sbin/critest

        # Verify 
        sudo crictl --version && sudo critest --version || { echo '=== FAIL @ cri-tools install';exit 22; }

        # Configure crictl 
        sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock \
            || { echo '=== FAIL @ crictl config'; exit 33; }

        #cat /etc/crictl.yaml

        true
    } || {
        echo "=== FAIL @ cri-tools install"
        exit 44
    }

    ## Reset config.toml for kubernetes (Enable CRI-Integration plugin)
    ## UPDATE : Use local script directly through ssh. See provision.sh
    #sudo cp -p /etc/containerd/config.toml /etc/containerd/config.toml.docker_default
    #ssh a1 "printf '$(<etc.containerd.config-cka.toml)' |sudo tee /etc/containerd/config.toml"
    #containerd config default |sudo tee /etc/containerd/config.toml
    #sudo cp -p etc.containerd.config.toml /etc/containerd/config.toml
    #sudo cp -p etc.containerd.config-cka.toml /etc/containerd/config.toml
    ## CRI Plugin config : Cgroup Driver
    ## https://github.com/containerd/containerd/blob/main/docs/cri/config.md#cri-plugin-config-guide
    ### SystemdCgroup = true
    ## Also configure for systemd @ /var/lib/kubelet/config.yaml
    
    ## Apply changes
    #sudo systemctl restart containerd
}

#the_hard_way
the_easy_way

# Configure docker 
docker_config(){
    # Post-install
    [[ $(type -t docker) ]] && {
        echo '@ Docker config : group/user'
        # Create docker group, add current user to group, and activate changes now.
        [[ $(groups |grep docker) ]] || {
            sudo groupadd docker
            sudo usermod -aG docker $USER
            newgrp docker
        }
        # UPDATE: Perform systemctl config later, after other reconfig/restart of containerd.
        # # Configure Docker server (service) to start on boot
        # sudo systemctl --now enable containerd.service
        # sudo systemctl --now enable docker.service
        # sudo systemctl status docker.service

        exit

    } || {
        echo "=== FAIL : REQUIREs docker"
    }
}

docker_config 
