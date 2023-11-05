#!/usr/bin/env bash
#
# VM provisioning : install RPMs 

# UPDATE : Tested @ RHEL 9.3 (Prior edit @ AlmaLinux 8.9)

# Install EPEL if not already
[[ $(dnf repolist |grep -i epel) ]] || sudo dnf -y install epel-release 

# [[ $(yum repolist all |grep epel) ]] || {
#     echo '=== EPEL : Install and enable'
#     sudo yum -y install epel-release 
#     sudo yum-config-manager --enable epel

#     sudo reboot 
# }

# Install utiARCH="amd64"
opts='--archlist x86_64,noarch --alldeps --resolve'
try='--nobest --allowerasing'

# EPEL : pkg: epel-release, Repo ID: epel : NOT @ ABC 
#sudo dnf -y download --nobest --allowerasing --alldeps --resolve epel-release 
#sudo dnf -y download --alldeps --resolve epel-release 
# sudo dnf -y install epel-release
# sudo yum-config-manager --enable epel # dnf has config-manager command
# sudo dnf config-manager --set-enabled epel

#sudo dnf -y update || sudo dnf -y $try update 
#sudo dnf -y makecache  

all='yum-utils dnf-plugins-core gcc make createrepo createrepo_c mkisofs ansible ansible-core iproute-tc bash-completion bind-utils tar nc socat rsync lsof wget curl tcpdump traceroute nmap arp-scan git httpd httpd-tools jq vim tree'

# printf "%s\n" $all |xargs -IX /bin/bash -c '
#     [[ $(type -t $1) ]] || { 
#         echo === @ $1
#         sudo dnf -y install $1
#     }
# ' _ X

sudo dnf -y install $all

# rpm -q --quiet yum-utils || {
#     echo '=== Install : yum-utils'
#     sudo dnf -y install yum-utils

#     sudo reboot
# }

[[ $(type -t haproxy) && $(type -t jq) ]] || {
    echo '=== HAProxy / Keepalived : Install'
    sudo dnf -y install keepalived haproxy psmisc 
}

add_docker_repo(){
	echo '=== Adding docker-ce.repo'
	# https://docs.docker.com/engine/install/centos/
	# https://linuxconfig.org/how-to-install-docker-in-rhel-8
	url='https://download.docker.com/linux/centos/docker-ce.repo'
	wget -nv $url
	[[ -f docker-ce.repo ]] || { echo '=== FAIL @ docker-ce repo';exit 0; }

	sudo dnf -y config-manager --add-repo docker-ce.repo
	#sudo dnf -y config-manager --set-enabled docker-ce.repo 
	#sudo yum-config-manager --enable docker-ce
	sudo dnf -y makecache
	#sudo yum -y update --nobest
	# RH broke docker-ce install by removing some of its dependencies, 
	# so download sans --resolve
}
[[ -f /etc/yum.repos.d/docker-ce.repo ]] || add_docker_repo

all='docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin'
# Log warns "cannot install best" on containerd dependency runc
sudo dnf -y install $try $all
