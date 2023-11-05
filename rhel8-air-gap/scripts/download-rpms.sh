#!/usr/bin/env bash
###############################################################
# Binaries not of RPM should be installed in /usr/local/bin/, 
# whereas RPM-installed binaries are in /usr/bin .
###############################################################
mkdir -p rpms/rhel8
pushd rpms/rhel8

echo "=== @ $PWD"


ARCH="amd64"
opts='--archlist x86_64,noarch --alldeps --resolve'
try='--nobest --allowerasing'
log="_dnf.download.opts.all.$(date '+%Y-%m-%dT%H.%M.%Z').log"

# EPEL : pkg: epel-release, Repo ID: epel : NOT @ ABC 
#sudo dnf -y download --nobest --allowerasing --alldeps --resolve epel-release 
#sudo dnf -y download --alldeps --resolve epel-release 
# sudo dnf -y install epel-release
# sudo yum-config-manager --enable epel # dnf has config-manager command
# sudo dnf config-manager --set-enabled epel

sudo dnf -y $try update  |& tee $log  
sudo dnf -y makecache  |& tee -a $log  

## Utilities
# If use "--arch x86_64" flag, then "No packages available"
all='yum-utils dnf-plugins-core gcc make createrepo createrepo_c mkisofs ansible ansible-core iproute-tc bash-completion bind-utils tar nc socat rsync lsof wget curl tcpdump traceroute nmap arp-scan git httpd httpd-tools jq vim tree'
# mkisofs is xorriso : The above also installs reposync
#sudo dnf -y download --nobest --allowerasing --alldeps --resolve $all # 198 packages
sudo dnf -y download $opts $all |& tee -a $log  
#... ~ 198 packages

# Kuberenetes RPMs
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
# https://kubernetes.io/releases/
#ver="$(curl -sSL https://dl.k8s.io/release/stable.txt)" # @ v1.29.2
arch='x86_64'
url=https://pkgs.k8s.io/core:/stable:/v1.29/rpm
all='kubelet kubeadm kubectl cri-tools kubernetes-cni'

add_k8s_repo(){
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
    sudo dnf -y makecache 
}
[[ -f /etc/yum.repos.d/kubernetes.repo ]] || add_k8s_repo

sudo dnf -y download $opts --disableexcludes=kubernetes $all |& tee -a $log 

# @ docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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
sudo dnf -y download $opts $all |& tee -a $log 
#sudo dnf -y download $opts $try $all |& tee -a $log 

# HAProxy / Keepalived
all='keepalived haproxy psmisc'
sudo dnf -y download $opts $all |& tee -a $log 

# # Trivy
# # RPM
# RELEASE_VERSION=$(grep -Po '(?<=VERSION_ID=")[0-9]' /etc/os-release)
# cat << EOF | sudo tee -a /etc/yum.repos.d/trivy.repo
# [trivy]
# name=Trivy repository
# baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$RELEASE_VERSION/\$basearch/
# gpgcheck=1
# enabled=1
# gpgkey=https://aquasecurity.github.io/trivy-repo/rpm/public.key
# EOF
# sudo dnf -y makecache

#sudo dnf -y download $opts trivy || sudo dnf -y download $opts $try trivy
echo "
    DONE. 

    See $log @ $(pwd) .
"
exit 0 
