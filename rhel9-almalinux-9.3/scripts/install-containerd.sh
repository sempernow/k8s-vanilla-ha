#!/usr/bin/env bash
###############################################################################
# Install container tools (idempotent):
# - binaries: containerd, runc, cri-tools (crictl, critest)
# - cni plugins
# (idempotent)
# https://kubernetes.io/docs/setup/production-environment/
###############################################################################
ARCH=${PRJ_ARCH:-amd64}

# @ runc, a low-level utility (for containerd)
# https://github.com/opencontainers/runc/releases
# https://github.com/containerd/containerd/blob/main/docs/getting-started.md
ver='1.1.12'
[[ $(runc -v 2>&1 |grep $ver) ]] && {
    echo '=== runc : ALREADY INSTALLED'
} || {
    echo '=== Install : runc'
    url="https://github.com/opencontainers/runc/releases/download/v${ver}/runc.$ARCH"
    target=/usr/local/sbin/runc
    wget -nv $url && sudo install -m 0755 runc.$ARCH $target
}
[[ $(runc -v 2>&1 |grep $ver) ]] || { 
    echo '=== FAIL @ runc install/update'
    exit 22
}
runc -v

# @ CNI Plugins (for containerd)
# https://github.com/containernetworking/plugins/releases
ver='1.4.1'
target_parent=/opt/cni/bin
[[ $($target_parent/loopback 2>&1 |grep $ver) ]] && {
    echo '=== CNI Plugins : ALREADY INSTALLED'
} || {
    echo '=== Install : CNI Plugins (for containerd)'
    tarball="cni-plugins-linux-${ARCH}-v${ver}.tgz"
    url="https://github.com/containernetworking/plugins/releases/download/v${ver}/$tarball"
    wget -nv $url 
    sudo mkdir -p $target_parent
    sudo tar Cxavf $target_parent $tarball 
}
[[ $($target_parent/loopback 2>&1 |grep $ver) ]] || { 
    echo '=== FAIL @ CNI-Plugins install/update'
    exit 23
}
ls -hl /opt/cni/bin 

# @ containerd 
# https://github.com/containerd/containerd/blob/main/docs/getting-started.md
# https://github.com/containerd/containerd/releases
ver='1.7.14'
[[ $(containerd -v 2>&1 |grep $ver) ]] && {
    echo "=== containerd : ALREADY INSTALLED"
} || {
    echo "=== Install : containerd v$ver"
    # Install containerd binaries into /usr/local/bin/
    tarball=containerd-${ver}-linux-${ARCH}.tar.gz
    url=https://github.com/containerd/containerd/releases/download/v$ver/$tarball
    target_parent=/usr/local
    wget -nv $url
    sudo tar Cxavf $target_parent $tarball
        # $ ls -hl /usr/local/bin/
        # -rwxr-xr-x. 1 root root  53M containerd
        # -rwxr-xr-x. 1 root root 6.8M containerd-shim
        # -rwxr-xr-x. 1 root root 8.4M containerd-shim-runc-v1
        # -rwxr-xr-x. 1 root root  12M containerd-shim-runc-v2
        # -rwxr-xr-x. 1 root root  25M containerd-stress
        # -rwxr-xr-x. 1 root root  28M ctr

    # Install containerd.service 
    echo '=== Install : containerd.service'
    url=https://raw.githubusercontent.com/containerd/containerd/main/containerd.service 
    target_parent=/usr/local/lib/systemd/system
    sudo mkdir -p $target_parent
    sudo wget -nv -O $target_parent/containerd.service $url
}
[[ $(containerd -v 2>&1 |grep $ver) ]] || { 
    echo '=== FAIL @ containerd install/update'
    exit 21
}
containerd -v

# @ containerd config

## Load kernel modules on boot
conf='/etc/modules-load.d/k8s-containerd.conf'
[[ -f $conf ]] || {
    echo '=== Configure containerd (CRI runtime) : Load kernel modules on boot'
    ## br_netfilter enables transparent masquerading and facilitates Virtual Extensible LAN (VxLAN) traffic for communication between Kubernetes pods across the cluster.
	cat <<-EOF |sudo tee $conf
	overlay
	br_netfilter
	EOF
    flag=1

    [[ -f $conf ]] || { 
        echo "=== FAIL @ containerd config : $conf NOT EXIST"
        #exit 40
    }
}

## Load kernel modules now
### modinfo br_netfilter           # Info
### modprobe -c |grep br_netfilter # Shows if CHANGEd
### lsmod |grep br_netfilter       # Shows if LOADED
[[ $(lsmod |grep overlay) ]] || sudo modprobe overlay  
[[ $(lsmod |grep overlay) ]] || { 
    echo '=== FAIL @ loading overlay module'
    #exit 30
}

[[ $(lsmod |grep br_netfilter) ]] || sudo modprobe br_netfilter  
[[ $(lsmod |grep br_netfilter) ]] || { 
    echo '=== FAIL @ loading br_netfilter module'
    #exit 31
}

## Set iptables bridging 
conf='/etc/sysctl.d/k8s-containerd.conf'
[[ -f $conf ]] || {
    echo '=== Configure containerd (CRI runtime) : Set iptables bridging'
	cat <<-EOF |sudo tee /etc/sysctl.d/k8s-containerd.conf
	net.bridge.bridge-nf-call-iptables  = 1
	net.bridge.bridge-nf-call-ip6tables = 1
	net.ipv4.ip_forward                 = 1
	EOF
    flag=1

    [[ -f $conf ]] || { 
        echo "=== FAIL @ containerd config : $conf NOT EXIST"
        #exit 40
    }
    ## Apply sysctl params without reboot
    sudo sysctl --system
    ## Show settings (k = v)
    #sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
}

## containerd config (TOML)
## Print default : 
## containerd config default |sudo tee /etc/containerd/config.toml
export registry=registry.k8s.io
conf='/etc/containerd/config.toml'
[[ -f $conf ]] || {
    sudo mkdir -p /etc/containerd
	cat <<-EOH |sudo tee $conf
	# containerd configuration for K8s (runc and systemd)
	version = 2
	[plugins]
	[plugins."io.containerd.grpc.v1.cri"]
	  sandbox_image = "$registry/pause:3.9"
	  [plugins."io.containerd.grpc.v1.cri".containerd]
	  discard_unpacked_layers = true
	  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
	    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
	      runtime_type = "io.containerd.runc.v2"
	      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
	        SystemdCgroup = true
	EOH
    [[ -f $conf ]] || { 
        echo "=== FAIL @ containerd config : $conf NOT EXIST"
        #exit 40
    }
}
sudo systemctl enable --now containerd.service
systemctl status containerd.service

# @ cri-tools; kubernetes-sigs project : crictl + critest
# https://github.com/kubernetes-sigs/cri-tools
# https://github.com/kubernetes-sigs/cri-tools/releases/
ver='v1.29.0'
[[ $(crictl -v 2>&1 |grep $ver) ]] || {
    echo '=== Download/Install : cri-tools'
    base_url="https://github.com/kubernetes-sigs/cri-tools/releases/download/$ver"
    target_parent=/usr/local/bin

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

    # CRI tools require sudo to run, yet are not in sudo PATH, so create soft link
    [[ -f /usr/local/bin/crictl ]] || {
        [[ -f /usr/sbin/crictl  ]] || sudo ln -s /usr/sbin/crictl /usr/local/bin/crictl
    }
    [[ -f /usr/local/bin/critest ]] || {
        [[ -f /usr/sbin/critest ]] || sudo ln -s /usr/sbin/critest /usr/local/bin/critest
    }
    # Verify sudoer access 
    sleep 1 # Allow for (NFS) latency
    sudo crictl --version >/dev/null 2>&1 ;(( $? )) && { echo '=== FAIL @ crictl sudoer config'; exit 40; }
    sudo critest --version >/dev/null 2>&1 ;(( $? )) && { echo '=== FAIL @ critest sudoer config'; exit 41; }

    # Configure crictl to containerd 
    sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock \
        || { echo '=== FAIL @ crictl config';exit 26; }

    # Configure crictl to run sans sudo by users of group "containerd"
    # UPDATE : Move to configure-services.sh and configure-user.sh
    # ## Create group for containerd:
    # gid=$(getent group containerd |cut -d':' -f3)
    # [[ $gid ]] || {
    #     sudo groupadd containerd
    #     gid=$(getent group containerd |cut -d':' -f3)
    # }
    # [[ $gid ]] || { echo '=== FAIL @ crictl : create group "containerd"';exit 27; }

    # ## Change group of containerd socket:
    # socket=/var/run/containerd/containerd.sock
    # [[ $(sudo ls -l $socket) ]] \
    #     && sudo chown :$gid $socket \
    #     || { echo "=== FAIL @ crictl : change group of $socket";exit 28; }

    # ## Add user to containerd group lest already member or is root:
    # [[ ! $(groups |grep containerd) && "$(id -u)" != "0" ]] && {
    #     sudo usermod -aG containerd $USER || { 
    #         echo "=== FAIL @ crictl : adding user '$USER' to group 'containerd'"
    #         exit 29
    #     }
    # }
    true

} || { echo '=== FAIL @ crictl install/update';exit 20; }
crictl -v
critest --version 

exit 0
######


# nerdctl : Docker-compatible CLI for containerd 
# https://github.com/containerd/nerdctl
# https://github.com/containerd/nerdctl/releases
echo "=== nerdctl (full) : DOWNLOAD ONLY"
ver='1.7.3'
tarball=nerdctl-full-${ver}-linux-${ARCH}.tar.gz
# Full : bin/ (binaries), lib/ (systemd configs), libexec/ (cni plugins), share/ (docs)
base_url=https://github.com/containerd/nerdctl/releases/download/v${ver}
echo '=== Download/Install : nerdctl + dependencies'
target_parent=/usr/local/bin
wget -nv $base_url/$tarball && sudo tar Cxavf $target_parent $tarball 
echo "=== nerdctl install/config : TODO"
