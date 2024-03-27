#!/usr/bin/env bash
###############################################################################
# Install and configure all container-related binaries:
# containerd, runc, cni-plugins, cri-tools.
#
# - Idempotent.
###############################################################################
ARCH=${PRJ_ARCH:-amd64}
task='Install/Update'
unset flag 

[[ -d $1 ]] || {
    echo "Directory does NOT EXIST : $1"
    exit 0
}
#cd '/tmp/k8s-air-gap-install'
pushd "$1"

# @ runc, a low-level utility (for containerd)
# https://github.com/opencontainers/runc/releases
# https://github.com/containerd/containerd/blob/main/docs/getting-started.md
ver='1.1.12'
[[ $(runc -v 2>&1 |grep $ver) ]] || {
    echo "=== $task  : runc"
    sudo cp -p runc.$ARCH/runc.$ARCH /usr/local/sbin/runc
    runc -v 
    flag=1
}
[[ $(runc -v 2>&1 |grep $ver) ]] || { echo '=== FAIL @ runc install/update';exit 22; }

# @ CNI Plugins (for containerd)
# https://github.com/containernetworking/plugins/releases
ver='1.4.0'
[[ $(/opt/cni/bin/loopback 2>&1 |grep $ver) ]] || {
    echo '=== Install : CNI Plugins (for containerd)'
    find cni-plugins -maxdepth 1 -type f -exec sudo cp {} /opt/cni/bin/ \;
    ls -hl /opt/cni/bin/loopback
    flag=1
}
[[ $(/opt/cni/bin/loopback 2>&1 |grep $ver) ]] || { echo '=== FAIL @ cni-plugins';exit 25; }

# @ containerd 
# https://github.com/containerd/containerd/blob/main/docs/getting-started.md
# https://github.com/containerd/containerd/releases
ver='1.7.13'
[[ $(containerd -v 2>&1 |grep $ver) ]] || {
    echo "=== $task : containerd v$ver"
    find containerd -maxdepth 1 -type f -exec sudo cp {} /usr/local/bin/ \;
    #ls -hl /usr/local/bin
    containerd -v
    flag=1

    # Install containerd.service 
    echo "=== $task  : containerd.service"
    sudo mkdir -p /usr/local/lib/systemd/system/
    sudo cp containerd/systemd/containerd.service /usr/local/lib/systemd/system/
    sudo chmod 0644 /usr/local/lib/systemd/system/containerd.service 
    #ls -hl /usr/local/lib/systemd/system/
}
[[ $(containerd -v 2>&1 |grep $ver) ]] || { echo '=== FAIL @ containerd install/update';exit 30; }

# @ containerd config

## Load kernel modules on boot
conf='/etc/modules-load.d/k8s-containerd.conf'
[[ -f $conf ]] || {
    echo '=== Configure containerd (CRI runtime) : Load kernel modules on boot'
    ## br_netfilter enables transparent masquerading and facilitates Virtual Extensible LAN (VxLAN) traffic for communication between Kubernetes pods across the cluster.
	cat <<-EOF |sudo tee /etc/modules-load.d/k8s-containerd.conf
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
## Insecure registry :
#export registry_mirror='http://ONXWQBLCS121.entds.ngisn.com:5000'
export registry="http://${CNCF_REGISTRY_HOST}:5000"

conf='/etc/containerd/config.toml'
[[ -f $conf ]] || {
    sudo mkdir -p /etc/containerd
	cat <<-EOH |sudo tee $conf
	# containerd configuration for K8s (runc and systemd) and registry ($registry) 
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
	  [plugins."io.containerd.grpc.v1.cri".registry]
	    [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
	      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."$registry"]
	        endpoint = ["http://$registry"]
        [plugins."io.containerd.grpc.v1.cri".registry.configs]
          [plugins."io.containerd.grpc.v1.cri".registry.configs."$registry".tls]
            insecure_skip_verify = true
	EOH
    flag=1
    [[ -f $conf ]] || { 
        echo "=== FAIL @ containerd config : $conf NOT EXIST"
        #exit 40
    }
}

#sudo systemctl enable --now containerd.service
#systemctl status containerd.service

# @ cri-tools, a kubernetes-sigs project : crictl + critest
# https://github.com/kubernetes-sigs/cri-tools
# https://github.com/kubernetes-sigs/cri-tools/releases/
ver='v1.29.0'
[[ $(crictl --version 2>&1 |grep $ver) ]] || {
    echo "=== $task : cri-tools"
    find cri-tools -maxdepth 1 -type f -exec sudo cp {} /usr/sbin/ \;
    sudo chmod 0755 /usr/sbin/cri*
    flag=1
}
[[ $(sudo crictl --version 2>&1 |grep $ver) ]] || {
    echo 'Make sudo link to cri-tools'

    # CRI tools require sudo to run, yet are not in sudo PATH, so create soft link
    sudo rm -f /usr/local/bin/crictl
    sudo rm -f /usr/local/bin/critest
    sudo ln -s /usr/sbin/crictl /usr/local/bin/crictl
    sudo ln -s /usr/sbin/critest /usr/local/bin/critest
    
    sleep 1
    flag=1

    # Verify sudoer access 
    sudo crictl --version >/dev/null 2>&1 ;(( $? )) && { echo '=== FAIL @ crictl sudoer config'; exit 40; }
    sudo critest --version >/dev/null 2>&1 ;(( $? )) && { echo '=== FAIL @ critest sudoer config'; exit 41; }

    # Configure crictl to containerd 
    sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock \
        || { echo '=== FAIL @ crictl config';exit 26; }

    #... for services and user config : See configure-services.sh

} || { echo '=== FAIL @ crictl install/update';exit 20; }

# nerdctl : Docker-compatible CLI for containerd 
# https://github.com/containerd/nerdctl
# https://github.com/containerd/nerdctl/releases
# Full : bin/ (binaries), lib/ (systemd configs), libexec/ (cni plugins), share/ (docs)
# echo "=== Install : nerdctl (full)"
# ver='1.7.3'
# mkdir -p nerdctl-${ver} 
# pushd nerdctl-${ver} 
# tarball=nerdctl-full-${ver}-linux-${ARCH}.tar.gz
# base_url=https://github.com/containerd/nerdctl/releases/download/v${ver}
# echo '=== Download/Install : nerdctl + dependencies'
# target_parent=/usr/local/bin
# wget -nv $base_url/$tarball #&& tar -xaf $tarball 
# popd 

[[ $flag ]] && {
    echo "=== SUCCESS"
} || {
    echo "=== NO CHANGE : Already installed."
}
popd
exit 0
######
