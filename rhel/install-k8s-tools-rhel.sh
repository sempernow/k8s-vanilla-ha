#!/usr/bin/env bash
# Install K8s-core tools using RPM Method 
# (Manual method (sans package manager) is another option.)
# @ https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
## RHEL7+ (Migrate to RHEL8 by replacing yum with dnf.)

[[ $(type -t etcd) ]] || { echo '=== REQUIREs etcd';exit 1; }

[[ $(yum repolist all |grep kubernetes) ]] || {
	echo '=== Add the Kubernetes repo'
	ver='1.28'
	url=https://pkgs.k8s.io/core:/stable:/v${ver}/rpm
	# >>>  MUST PRESERVE TABs at HEREDOC lines  <<<
	cat <<-EOH |sudo tee /etc/yum.repos.d/kubernetes.repo
	[kubernetes]
	name=Kubernetes
	baseurl=${url}/
	enabled=1
	gpgcheck=1
	gpgkey=${url}/repodata/repomd.xml.key
	exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
	EOH
    sudo yum -y makecache
    sudo yum -y update
}

## This RPM-install method installs: 
## - K8s tools (kubelet, kubeadm, kubectl) @ /usr/bin/
## - CNI Plugins (19) @ /opt/cni/bin/
## - CRI Tools (crictl, critest) @ /usr/local/bin/
## - containerd @ /usr/local/bin/
echo '=== Install K8s-core tools : kubelet, kubeadm, kubectl'
sudo yum -y install kubelet kubeadm kubectl --disableexcludes=kubernetes

kubelet --version;(( $? )) && { echo '=== FAIL @ kubelet install'; exit 10; }
kubeadm version;(( $? )) && { echo '=== FAIL @ kubeadm install'; exit 11; }
kubectl version --client=true;(( $? )) && { echo '=== FAIL @ kubectl install'; exit 12; }
containerd -v;(( $? )) && { echo '=== FAIL @ containerd install'; exit 13; }
## See /etc/containerd/config.toml (local @ containerd-config.toml)
#containerd config dump

echo '=== Enable/Start kubelet.service'
sudo systemctl enable --now kubelet

