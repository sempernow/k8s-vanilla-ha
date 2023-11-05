#!/usr/bin/env bash
# Install K8s-core tools using RPM Method 
# (Manual method (sans package manager) is another option.)
# @ https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl

all='kubelet kubeadm kubectl cri-tools kubernetes-cni'

# Add/Enable repo (manually) if not already
[[ $(dnf repolist |grep kubernetes) ]] || {
    k8s_version=${K8S_VERSION.*}
	ver=${k8s_version:-1.29}
	echo "=== Add the Kubernetes v$ver repo of pkgs.k8s.io"
	url=https://pkgs.k8s.io/core:/stable:/v${ver}/rpm
	# >>>  MUST PRESERVE TABs at HEREDOC lines  <<<
	cat <<-EOH |sudo tee /etc/yum.repos.d/kubernetes.repo
	[kubernetes]
	name=Kubernetes
	baseurl=${url}/
	enabled=1
	gpgcheck=1
	gpgkey=${url}/repodata/repomd.xml.key
	exclude=$all
	EOH
    
    # Update repo metadata
    sudo dnf -y makecache
}

echo "=== Install K8s-core tools : $all"
## This RPM-install method installs: 
## - K8s tools (kubelet, kubeadm, kubectl) @ /usr/bin/
## - CNI Plugins (19) @ /opt/cni/bin/
## - CRI Tools (crictl, critest) @ /usr/local/bin/
## - containerd @ /usr/local/bin/
sudo dnf -y install --disableexcludes=kubernetes $all

# Verify
kubelet --version;(( $? )) && { echo '=== FAIL @ kubelet install'; exit 10; }
kubeadm version;(( $? )) && { echo '=== FAIL @ kubeadm install'; exit 11; }
kubectl version --client=true;(( $? )) && { echo '=== FAIL @ kubectl install'; exit 12; }
containerd -v;(( $? )) && { echo '=== FAIL @ containerd install'; exit 13; }
crictl --version;(( $? )) && { echo '=== FAIL @ cri-tools install'; exit 14; }

## See /etc/containerd/config.toml (local @ containerd-config.toml)
#containerd config dump

echo '=== Enable/Start kubelet.service'
[[ $(type -t etcd) ]] || { echo '=== REQUIREs etcd';exit 1; }
sudo systemctl enable --now kubelet

