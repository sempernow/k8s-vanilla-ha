#!/usr/bin/env bash
#
# VM provisioning : install RPMs
#
# Install some packages and then reboot
# to prevent out-of-memory errors that otherwise occur
# due to shortcomings of dynamic memory allocation.

[[ $(yum repolist all |grep epel) ]] || {
    echo '=== EPEL : Install and enable'
    sudo yum -y install epel-release 
    sudo yum-config-manager --enable epel

    sudo reboot 
}

rpm -q --quiet yum-utils || {
    echo '=== Install : yum-utils'
    sudo yum -y install yum-utils

    sudo reboot
}

[[ $(yum repolist all |grep docker-ce) ]] || {
    echo '=== Docker CE : Add repo'
    url='https://download.docker.com/linux/centos/docker-ce.repo'
    #sudo dnf -y config-manager --add-repo $url
    sudo yum-config-manager --add-repo $url
    sudo yum-config-manager --enable docker-ce
    sudo yum -y makecache
    sudo yum -y update
    
    sudo reboot
}

[[ $(type -t haproxy) && $(type -t jq) ]] || {
    echo '=== HAProxy / Keepalived : Install'
    sudo yum -y install keepalived haproxy psmisc 

    echo '=== Tools for kubeadm : Install some network utilities'
    sudo yum -y install iproute-tc bash-completion bind-utils tar nc lsof wget curl git jq vim tree

    sudo reboot
}

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
	#sudo dnf -y update
    sudo yum -y makecache
    sudo yum -y update
    
    sudo reboot
}
