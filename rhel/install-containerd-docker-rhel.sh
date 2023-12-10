#!/usr/bin/env bash
# - Install containerd as the CRI runtime for Kubernetes. 
# - Install Docker CE server and client.
# REF:
#   https://kubernetes.io/docs/setup/production-environment/
#   https://github.com/containerd/containerd/releases

ARCH=amd64 

[[ $(type -t dnf) ]] || { echo '=== REQUIREs dnf Package Manager'; exit 99; } 

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

# Docker CE + containerd + ...
container_tools(){
    # https://docs.docker.com/engine/install/centos/
    rpm -q --quiet yum-utils || {
        echo '=== Install : yum-utils'
        sudo yum -y install yum-utils
    }
    [[ $(dnf repolist |grep docker-ce) ]] || {
        echo '=== Add repo: docker-ce'
        url='https://download.docker.com/linux/centos/docker-ce.repo'
        sudo dnf -y config-manager --add-repo $url
        sudo yum -y update
    }
    echo '=== Install : Docker CE + containerd.io'
    sudo yum -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    docker -v >/dev/null 2>&1 ;(( $? )) && { echo '=== FAIL @ docker install'; exit 11; }
    dockerd -v >/dev/null 2>&1 ;(( $? )) && { echo '=== FAIL @ dockerd install'; exit 12; }
    containerd -v >/dev/null 2>&1 ;(( $? )) && { echo '=== FAIL @ containerd install'; exit 13; }


    # Install/Update cri-tools, a kubernetes-sigs project : crictl + critest
    # https://github.com/kubernetes-sigs/cri-tools
    # https://github.com/kubernetes-sigs/cri-tools/releases/
    ver='v1.28.0'
    [[ $(crictl -v 2>&1 |grep $ver) ]] || {
        base_url="https://github.com/kubernetes-sigs/cri-tools/releases/download/$ver"
        target_parent=/usr/local/bin

        echo '=== Download/Install : cri-tools'

        echo '=== Install : crictl'
        tarball="crictl-${ver}-linux-${ARCH}.tar.gz"
        wget -nv $base_url/$tarball \
            && sudo tar Cxavf $target_parent $tarball 

        echo '=== Install : critest'
        tarball="critest-${ver}-linux-${ARCH}.tar.gz"
        wget -nv $base_url/$tarball \
            && sudo tar Cxavf $target_parent $tarball 
    }
    [[ $(crictl -v 2>&1 |grep $ver) ]] && {
        echo '=== Configure : cri-tools'
        # CRI tools require sudo to run, yet they are not in sudo PATH, so create soft link
        sudo ln -s /usr/local/bin/crictl  /usr/sbin/crictl
        sudo ln -s /usr/local/bin/critest /usr/sbin/critest

        # Verify (@ sudoer access) 
        sudo crictl -v >/dev/null 2>&1 ;(( $? )) && { echo '=== FAIL @ crictl sudoer config'; exit 24; }
        sudo critest -v >/dev/null 2>&1 ;(( $? )) && { echo '=== FAIL @ critest sudoer config'; exit 25; }

        # Configure crictl 
        sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock \
            || { echo '=== FAIL @ crictl config';exit 26; }
    } || { echo '=== FAIL @ crictl install/update';exit 20; }


    # Install/Update containerd 
    # https://github.com/containerd/containerd/blob/main/docs/getting-started.md
    ver='1.7.9'
    [[ $(containerd -v 2>&1 |grep $ver) ]] || {
        echo '=== Install : containerd'
        # Install containerd binaries into /usr/local/bin/
        url=https://github.com/containerd/containerd/releases/download/v$ver/containerd-${ver}-linux-${ARCH}.tar.gz
        target_parent=/usr/local
        wget -nv $url
        sudo tar Cxavf $target_parent containerd-${ver}-linux-${ARCH}.tar.gz

        # Install containerd.service 
        echo '=== Install : containerd.service'
        url=https://raw.githubusercontent.com/containerd/containerd/main/containerd.service 
        target_parent=/usr/local/lib/systemd/system
        sudo mkdir -p $target_parent
        sudo wget -nv -O $target_parent/containerd.service $url

        # Configure later : See config-cka.toml
    }
    [[ $(containerd -v 2>&1 |grep $ver) ]] || { echo '=== FAIL @ containerd install/update';exit 21; }


    # Install/Update runc, a low-level utility (for containerd)
    # https://github.com/opencontainers/runc/releases
    # https://github.com/containerd/containerd/blob/main/docs/getting-started.md
    ver='1.1.10'
    [[ $(runc -v 2>&1 |grep $ver) ]] || {
        echo '=== Install : runc'
        url=https://github.com/opencontainers/runc/releases/download/v${ver}/runc.$ARCH
        target=/usr/local/sbin/runc
        wget -nv $url && sudo install -m 0755 runc.$ARCH $target
    }
    [[ $(runc -v 2>&1 |grep $ver) ]] || { echo '=== FAIL @ runc install/update';exit 22; }


    # Install/Update CNI Plugins (for containerd)
    # https://github.com/containernetworking/plugins/releases
    ver='1.4.0'
    target_parent=/opt/cni/bin
    [[ $($target_parent/portmap 2>&1 |grep $ver) ]] || {
        echo '=== Install : CNI Plugins (for containerd)'
        tarball="cni-plugins-linux-${ARCH}-v${ver}.tgz"
        url="https://github.com/containernetworking/plugins/releases/download/v${ver}/$tarball"
        wget -nv $url 
        sudo mkdir -p $target_parent
        sudo tar Cxavf $target_parent $tarball 
    }
    [[ $($target_parent/portmap 2>&1 |grep $ver) ]] || { echo '=== FAIL @ CNI-Plugins install/update';exit 23; }
}
container_tools

docker_config(){
    # Post-install
    [[ $(type -t docker) ]] && {
        [[ $(groups |grep docker) ]] || {
            echo "Configure : create docker group, and add the current user ($USER)"
            sudo groupadd docker
            sudo usermod -aG docker $USER
            newgrp docker
        }
        # Perform systemctl config later, after other reconfig/restart of containerd.
    }
}
docker_config 

echo '=== Tools installed:'
docker -v
dockerd -v
containerd -v
runc -v
crictl -v
critest --version 
