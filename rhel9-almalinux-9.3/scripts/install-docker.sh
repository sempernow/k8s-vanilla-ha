#!/usr/bin/env bash
# - Configure host network
# - Install containerd as the container runtime for Kubernetes. 
# - Install Docker CE server and client.
# REF:
#   https://kubernetes.io/docs/setup/production-environment/
#   https://github.com/containerd/containerd/releases

[[ $(type -t dnf) ]] || { echo '=== REQUIREs dnf Package Manager'; exit 99; } 
[[ $(type -t wget) ]] || { 
    sudo dnf -y install wget 
    [[ $(type -t wget) ]] || { echo === FAIL @ wget install;exit 98; }
} 

ARCH=${PRJ_ARCH:-amd64}

# Install Docker CE
# https://docs.docker.com/engine/install/centos/
rpm -q --quiet yum-utils || {
    echo '=== Install : yum-utils'
    sudo dnf -y install yum-utils
}
# Add/Enable docker-ce repo
[[ $(dnf repolist |grep docker-ce) ]] || {
    echo '=== Docker CE : Add/Enable repo'
    url='https://download.docker.com/linux/centos/docker-ce.repo'
    #sudo dnf -y config-manager --add-repo $url
    wget -nv -O /tmp/docker-ce.repo $url
    sudo dnf -y config-manager --add-repo file:///tmp/docker-ce.repo
    repoid=$(dnf repolist |cut -d' ' -f1 |grep docker-ce |head -n 1) # docker-ce-stable
    [[ $repoid ]] && sudo dnf -y config-manager --set-enabled $repoid || {
        echo 'FAIL @ add/enable docker-ce repo'
        exit 10
    }
    sudo rm -f /tmp/docker-ce.repo
    sudo dnf -y makecache
}

echo '=== Install : Docker CE (and containerd if not already)'
## NOTE this does NOT integrate Docker Engine (server) with Kubernetes, 
## even if both are configured to the same container-runtime socket.
## Integration requires a rapidly-evolving scheme, with prior/current schemes losing support.
## See https://github.com/Mirantis/cri-dockerd . Also see its configuration under Minikube. 
# Docker's containerd (cotnainerd.io) may be older; prefer newer.
[[ $(type -t containerd) ]] || sudo dnf -y install containerd.io # containerd --version #=> 1.6.28
    # -rwxr-xr-x. 1 root root  51M /usr/bin/containerd
    # -rwxr-xr-x. 1 root root 7.6M /usr/bin/containerd-shim
    # -rwxr-xr-x. 1 root root 9.6M /usr/bin/containerd-shim-runc-v1
    # -rwxr-xr-x. 1 root root 9.7M /usr/bin/containerd-shim-runc-v2
sudo dnf -y install docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin

docker -v >/dev/null 2>&1 ;(( $? )) && { echo '=== FAIL @ docker install'; exit 11; }
dockerd -v >/dev/null 2>&1 ;(( $? )) && { echo '=== FAIL @ dockerd install'; exit 12; }
containerd -v >/dev/null 2>&1 ;(( $? )) && { echo '=== FAIL @ containerd install'; exit 13; }

# Install cri-dockerd (shim) : Integrate Docker Engine (server) with Kubernetes
# https://github.com/Mirantis/cri-dockerd
# https://kubernetes.io/blog/2022/02/17/dockershim-faq/
# # Configure Kubernetes :
# sudo kubeadm init \
#     --pod-network-cidr=10.244.0.0/16 \
#     --cri-socket /run/cri-dockerd.sock
INSTALL_DOCKER_SHIM=false
[[ $INSTALL_DOCKER_SHIM ]] && {
    ver='0.3.9'
    [[ $(cri-dockerd --version 2>&1 |grep $ver) ]] || {
        echo '=== Download/Install : cri-dockerd (Docker/Kubernetes CRI shim)'
        # Download binary
        tarball="cri-dockerd-${ver}.${ARCH}.tgz"
        url=https://github.com/Mirantis/cri-dockerd/releases/download/v${ver}/$tarball
        wget -nv $url && tar -xaf $tarball && cd cri-dockerd || { echo '=== FAIL @ cri-dockerd download';exit 15; }
        # Install cri-dockerd binary
        sudo mkdir -p /usr/local/bin
        sudo install -o root -g root -m 0755 cri-dockerd /usr/local/bin/cri-dockerd
        # Download systemd units
        url="https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd"
        wget -nv $url/cri-docker.service || { echo '=== FAIL # cri-docker.service download';ecit 14; }
        wget -nv $url/cri-docker.socket || { echo '=== FAIL # cri-docker.socket download';ecit 15; }
        # Configure systemd units for cri-dockerd (service and socket)
        sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' cri-docker.service
        sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' cri-docker.service
        sudo cp -p cri-docker.socket /usr/lib/systemd/system/
        sudo cp -p cri-docker.service /usr/lib/systemd/system/
        sudo chown root:root /usr/lib/systemd/system/cri-docker.*
        sudo chmod 0644 /usr/lib/systemd/system/cri-docker.*
        # Enable/Start : Docker should be running first.
        # sudo systemctl daemon-reload
        # sudo systemctl enable --now cri-docker.socket
        # sudo systemctl enable --now cri-docker.service
    }
}

# Post-install
[[ $(type -t docker) ]] && {
    [[ $(groups |grep docker) ]] || {
        echo "Configure Docker CE : create docker group, and add the current user ($USER)"
        sudo groupadd docker
        sudo usermod -aG docker $USER
        sudo newgrp docker

        [[ "$(systemctl is-active containerd.service)" == 'active' ]] \
            && sudo systemctl enable --now docker.service
    }
    # Perform systemctl config later, after other reconfig/restart of containerd.
}


echo '=== Installed : Docker CE:'
docker -v
dockerd -v

echo '=== docker.service :'
systemctl status docker.service


