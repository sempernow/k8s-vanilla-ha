#!/usr/bin/env bash
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl

[[ $(dnf repolist |grep kubernetes) ]] || {
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
	sudo dnf -y update
}

echo '=== Install K8s-core tools : kubelet, kubeadm, kubectl'
sudo dnf -y install kubelet kubeadm kubectl --disableexcludes=kubernetes

kubelet --version >/dev/null 2>&1 ;(( $? )) && { echo '=== FAIL @ kubelet install'; exit 10; }
kubeadm version >/dev/null 2>&1 ;(( $? )) && { echo '=== FAIL @ kubeadm install'; exit 11; }
kubectl version >/dev/null 2>&1 ;(( $? )) && { echo '=== FAIL @ kubectl install'; exit 12; }

echo '=== Enable/Start kubelet.service'
sudo systemctl enable --now kubelet.service

echo '=== K8s-core tools are installed:'
kubelet --version
kubeadm version
kubectl version
