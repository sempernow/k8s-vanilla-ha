##############################################################################
## Makefile.settings : Environment Variables for Makefile(s)
#include Makefile.settings

##############################################################################
## Environment variable rules:
## - Any TRAILING whitespace KILLS its variable value and may break recipes.
## - ESCAPE only that required by the shell (bash).
## - Environment hierarchy:
##   - Makefile environment OVERRIDEs OS environment lest set using `?=`.
##  	  - `FOO ?= bar` is overridden by parent setting; `export FOO=new`.
##  	  - `FOO :=`bar` is NOT overridden by parent setting.
##   - Docker YAML `env_file:` OVERRIDEs OS and Makefile environments.
##   - Docker YAML `environment:` OVERRIDEs YAML `env_file:`.
##   - CMD-inline OVERRIDEs ALL REGARDLESS; `make recipeX FOO=new BAR=new2`.

##############################################################################
## $(INFO) : Usage : `$(INFO) 'What ever'` prints a stylized "@ What ever".
SHELL   := /bin/bash
YELLOW  := "\e[1;33m"
RESTORE := "\e[0m"
INFO    := @bash -c 'printf $(YELLOW);echo "@ $$1";printf $(RESTORE)' MESSAGE

##############################################################################
## Project Meta

export PRJ_ROOT := $(shell pwd)
export LOG_PREFIX := make.$(shell date '+%Y-%m-%dT%H.%M.%Z')

##############################################################################
## Cluster

## HAProxy/Keepalived : 
### VIP within targets' network mask
export HALB_VIP      ?= 192.168.0.100
export HALB_MASK     ?= 24
export HALB_CIDR     ?= ${HALB_VIP}/${HALB_MASK}
export HALB_VIP6     ?= ::ffff:c0a8:64
export HALB_PORT     ?= 8443
export HALB_DEVICE   ?= eth0
export HALB_FQDN_1   ?= a0.local
export HALB_FQDN_2   ?= a1.local
export HALB_FQDN_3   ?= a2.local

export HALB_ENDPOINT ?= ${HALB_VIP}:${HALB_PORT}

## ansibash 
## Public-key string of ssh user must be in ~/.ssh/authorized_keys of GITOPS_USER at all targets.
#export GITOPS_USER          ?= $(shell id -un)
#export GITOPS_USER          ?= gitops
export GITOPS_USER          ?= u1
export GITOPS_KEY           ?= ~/.ssh/vm_common
export GITOPS_NODES_MASTER  ?= a0 a1 a2
export GITOPS_NODES_WORKER  ?= a3 
export GITOPS_TARGET_LIST   ?= ${GITOPS_NODES_MASTER} ${GITOPS_NODES_WORKER}
export GITOPS_SRC_DIR       ?= $(shell pwd)
#export GITOPS_DST_DIR       ?= ${GITOPS_SRC_DIR}
export GITOPS_DST_DIR       ?= /tmp/$(shell basename "${GITOPS_SRC_DIR}")

export ANSIBASH_TARGET_LIST ?= ${GITOPS_TARGET_LIST}
export ANSIBASH_USER        ?= ${GITOPS_USER}

## Configurations : https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/
## K8s RELEASEs https://kubernetes.io/releases/
export K8S_VERSION            ?= 1.29.3
#export K8S_VERSION            ?= 1.28.6
export K8S_PROVISIONER        ?= ${GITOPS_USER}
export K8S_PROVISIONER_KEY    ?= ~/.ssh/vm_common
export K8S_REGISTRY           ?= registry.k8s.io
export K8S_VERBOSITY          ?= 5
export K8S_INIT_NODE_SSH      ?= $(shell echo ${GITOPS_NODES_MASTER} |cut -d' ' -f1)
export K8S_INIT_NODE          ?= ${K8S_INIT_NODE_SSH}.local
export K8S_KUBEADM_CONFIG     ?= kubeadm-config.yaml
export K8S_IMAGE_REPOSITORY   ?= registry.k8s.io
export K8S_CONTROL_PLANE_IP   ?= ${HALB_VIP}
export K8S_CONTROL_PLANE_PORT ?= ${HALB_PORT}
#export K8S_SERVICE_CIDR       ?= 10.55.0.0/12
export K8S_SERVICE_CIDR       ?= 10.96.0.0/12
#export K8S_POD_CIDR           ?= 10.20.0.0/16
export K8S_POD_CIDR           ?= 10.244.0.0/24
export K8S_CRI_SOCKET         ?= unix:///var/run/containerd/containerd.sock
export K8S_CGROUP_DRIVER      ?= systemd
## K8S_BOOTSTRAP_TOKEN=$(kubeadm token generate)
export K8S_BOOTSTRAP_TOKEN    ?= ojt3kn.5kin2no0pyy554eh
## K8S_CERTIFICATE_KEY=$(kubeadm certs certificate-key)
export K8S_CERTIFICATE_KEY    ?= fb594fa0b1af4fef77045ba76afd3029146557c70677d6f0b447aeac37ffb8ea
## K8S_CA_CERT_HASH="sha256:$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt |openssl rsa -pubin -outform der 2>/dev/null |openssl dgst -sha256 -hex |sed 's/^.* //')"
export K8S_CA_CERT_HASH       ?= sha256:bd55cff35321450ff0fdece0f1b7e3987a96a437dcad866fdf8ff40c1a0e549c 


#export K8S_INSTALL_DIR ?= k8s-air-gap-install

##############################################################################
## Recipes : Meta

menu :
	$(INFO) 'K8s on RHEL9 : Install (in preferred order)'
	@echo "env          : Print Makefile environment"
	@echo "pki          : Setup this user's PKI at remote provisioner account"
	@echo "pki2         : Same but automated. Requires user having root access sans password"
	@echo "hello        : hostname and user at target(s)"
	@echo "prep         : Configure /etc/hosts"
	@echo "rpms         : Install all RPM packages"
	@echo "bins         : Install binaries"
	@echo "post         : Configure services, swap, SELinux, and user (${ANSIBASH_USER})"
	@echo "etcd-test    : Smoke test etcd"
	@echo "lbinstall    : Install HA-LB RPMs"
	@echo "lbmake       : Generate HA-LB configurations from .tpl files"
	@echo "lbconf       : Configure HA LB on all control nodes"
	@echo "lbverify     : Verify HA-LB dynamics"
	@echo "============== "
	@echo "conf-gen     : Generate ${K8S_KUBEADM_CONFIG} from .tpl"
	@echo "conf-push    : Upload ${K8S_KUBEADM_CONFIG} to all nodes"
	@echo "conf-pull    : Pull images for subsequent kubeadm init"
	@echo "init-pre     : kubeadm init phase preflight"
	@echo "init         : kubeadm init"
	@echo "join-workers : kubeadm join"
	@echo "conf-kubectl : Make ~/.kube/config"
	@echo "nodes        : kubectl get nodes"


env : 
	$(INFO) 'Environment'
	@echo "PWD=${PRJ_ROOT}"
	@env |grep HALB_ 
	@env |grep K8S_
	@env |grep GITOPS_ 


perms :
	find . -type f ! -path './.git/*' -exec chmod 0644 "{}" \+
	find . -type f ! -path './.git/*' -iname '*.sh' -exec chmod 0755 "{}" \+

    ##... Each affected file has mtime RESET by `make perms`

#ansibash sudo firewall-cmd --permanent --zone=public --service=k8s-workers --add-interface=cni0
foo :
	echo ${GITOPS_SRC_DIR}
	echo /tmp/$(shell basename "${GITOPS_SRC_DIR}")

##############################################################################
## Recipes : Cluster

# Scan subnet (CIDR) for IP addresses in use (running machines).
# - Manually validate that HALB_VIP is set to an *unused* address (within subnet CIDR).
# - Note this does not guarantee that an available VIP will remain so.
# - Protecting a VIP requires network admin.
scan :
	nmap -sn ${HALB_CIDR} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.scan.nmap.log
	sudo arp-scan --interface ${HALB_DEVICE} --localnet \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.scan.arp-scan.log

hello :
	ansibash -c 'hostname && id -un'

pkitest : 
	ansibash 'sudo ls -hl /etc/sudoers.d/'

# Setup gitops user on each node; final task is manual
# Setup @ each node: bash create_provisioner_target_node.sh "$(cat vm_common.pub)"
# Test : with GITOPS_USER set to provioner : ansibash sudo cat /etc/sudoers.d/gitops
pki :
	printf "%s\n" ${GITOPS_TARGET_LIST} |xargs -I{} scp ${GITOPS_KEY}.pub {}:. 
	printf "%s\n" ${GITOPS_TARGET_LIST} |xargs -I{} scp create_provisioner_target_node.sh {}:. 

# Requires USER to have root access sans password
pki2 :
	GITOPS_USER=${USER} ansibash -s create_provisioner_target_node.sh '$(shell cat ${GITOPS_KEY}.pub)'

prep : 
	ansibash -s ${GITOPS_SRC_DIR}/scripts/selinux-permissions.sh
	ansibash -s ${GITOPS_SRC_DIR}/scripts/firewalld-k8s.sh
	ansibash -s ${GITOPS_SRC_DIR}/scripts/firewalld-istio.sh
	ansibash -s ${GITOPS_SRC_DIR}/scripts/firewalld-calico.sh 
	ansibash sudo firewall-cmd --reload 
	ansibash sudo dnf -y update
	ansibash sudo dnf -y makecache

.PHONY: rpms etcd

rpms rpm : 
	ansibash -s ${GITOPS_SRC_DIR}/scripts/install-rpms.sh  \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.rpms.install-rpms.log

bins bin :
	ansibash -s ${GITOPS_SRC_DIR}/scripts/install-containerd.sh \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.rpms.install-containerd.log
	ansibash -s ${GITOPS_SRC_DIR}/scripts/install-bins.sh \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.bins.install-bins.log

#ansibash -s ${GITOPS_SRC_DIR}/scripts/install-bins.sh ${GITOPS_DST_DIR}

#ansibash -s ${GITOPS_SRC_DIR}/scripts/install-containerd-air-gap.sh ${GITOPS_DST_DIR}

post : 
	ansibash -s ${GITOPS_SRC_DIR}/scripts/configure-services.sh 
	ansibash -s ${GITOPS_SRC_DIR}/scripts/swap-off.sh 
	ansibash -s ${GITOPS_SRC_DIR}/scripts/selinux-permissive.sh 
	ansibash -s ${GITOPS_SRC_DIR}/scripts/configure-user.sh ${GITOPS_USER}
	rm -f ~/.ssh/master-${GITOPS_USER}*

etcd-test :
	ansibash -s ${GITOPS_SRC_DIR}/scripts/etcd-test.sh \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.etcd-test.log

#ansibash -s ${GITOPS_SRC_DIR}/scripts/install-containerd-air-gap.sh ${GITOPS_DST_DIR}

#################################
# END Air-gap Makefile recipes
# Use Makefile of PRJ root
#################################

lbinstall :
	ansibash sudo yum -y install keepalived haproxy psmisc 

#bash make.recipes.sh halb
lbmake :
	bash ${GITOPS_SRC_DIR}/halb/build-halb.sh
	

# bash halb/push-halb.sh
lbconf :
	scp -p ${GITOPS_SRC_DIR}/halb/keepalived-${HALB_FQDN_1}.conf ${GITOPS_USER}@${HALB_FQDN_1}:keepalived.conf
	scp -p ${GITOPS_SRC_DIR}/halb/keepalived-${HALB_FQDN_2}.conf ${GITOPS_USER}@${HALB_FQDN_2}:keepalived.conf
	scp -p ${GITOPS_SRC_DIR}/halb/keepalived-${HALB_FQDN_3}.conf ${GITOPS_USER}@${HALB_FQDN_3}:keepalived.conf
	ansibash -u ${GITOPS_SRC_DIR}/halb/systemd/99-keepalived.conf 
	ansibash -u ${GITOPS_SRC_DIR}/halb/keepalived-check_apiserver.sh 
	ansibash -u ${GITOPS_SRC_DIR}/halb/haproxy.cfg 
	ansibash -u ${GITOPS_SRC_DIR}/halb/haproxy-rsyslog.conf 
	ansibash -u ${GITOPS_SRC_DIR}/halb/etc.hosts
	ansibash -u ${GITOPS_SRC_DIR}/halb/etc.environment
	ansibash -s ${GITOPS_SRC_DIR}/halb/firewalld-halb.sh ${HALB_VIP} ${HALB_VIP6} ${HALB_PORT} ${HALB_DEVICE}
	ansibash -s ${GITOPS_SRC_DIR}/halb/configure-halb.sh

lbverify : 
	bash ${GITOPS_SRC_DIR}/halb/verify-instruct.sh

lbfix :	
	ssh gitops@vm124 /bin/bash -s <${GITOPS_SRC_DIR}/halb/firewalld-halb.sh ${HALB_VIP} ${HALB_VIP6} ${HALB_PORT} ${HALB_DEVICE}

## Generate cluster PKI (if not exist) and declare kubeadm-relevant params at Makefile.settings 
conf-prep :
	ssh ${GITOPS_USER}@${K8S_INIT_NODE_SSH} /bin/bash -s < \
		${GITOPS_SRC_DIR}/scripts/conf-prep.sh ${K8S_INIT_NODE} ${K8S_KUBEADM_CONFIG} \
		|grep 'export K8S_' |& tee ${GITOPS_SRC_DIR}/scripts/conf-prep
	echo '## @ Makefile.settings : This file is DYNAMICALLY GENERATED  (See Makefile recipes)' \
		|tee Makefile.settings
	cat scripts/conf-prep |tee -a Makefile.settings

conf-gen :
	cat ${K8S_KUBEADM_CONFIG}.tpl \
		|sed 's#K8S_VERSION#${K8S_VERSION}#g' \
		|sed 's#K8S_REGISTRY#${K8S_REGISTRY}#g' \
		|sed 's#K8S_VERBOSITY#${K8S_VERBOSITY}#g' \
		|sed 's#K8S_INIT_NODE#${K8S_INIT_NODE}#g' \
		|sed 's#K8S_IMAGE_REPOSITORY#${K8S_IMAGE_REPOSITORY}#g' \
		|sed 's#K8S_CONTROL_PLANE_IP#${K8S_CONTROL_PLANE_IP}#g' \
		|sed 's#K8S_CONTROL_PLANE_PORT#${K8S_CONTROL_PLANE_PORT}#g' \
		|sed 's#K8S_SERVICE_CIDR#${K8S_SERVICE_CIDR}#g' \
		|sed 's#K8S_POD_CIDR#${K8S_POD_CIDR}#g' \
		|sed 's#K8S_CRI_SOCKET#${K8S_CRI_SOCKET}#g' \
		|sed 's#K8S_CGROUP_DRIVER#${K8S_CGROUP_DRIVER}#g' \
		|sed 's#K8S_BOOTSTRAP_TOKEN#${K8S_BOOTSTRAP_TOKEN}#g' \
		|sed 's#K8S_CERTIFICATE_KEY#${K8S_CERTIFICATE_KEY}#g' \
		|sed 's#K8S_CA_CERT_HASH#${K8S_CA_CERT_HASH}#g' \
		|sed '/^ *#/d' |sed '/^\s*$$/d' \
		|tee ${K8S_KUBEADM_CONFIG}

conf-push :
	ansibash -u ${K8S_KUBEADM_CONFIG} 

conf-pull :
	ansibash sudo kubeadm config images pull -v${K8S_VERBOSITY} \
		--config ${K8S_KUBEADM_CONFIG} \
		|& tee kubeadm.config.images.pull.log

init-pre init-preflight :
	ansibash sudo kubeadm init phase preflight -v${K8S_VERBOSITY} \
		--config ${K8S_KUBEADM_CONFIG} \
		|& tee kubeadm.init.phase.preflight.log

init :
	ssh ${K8S_INIT_NODE_SSH} sudo kubeadm init -v${K8S_VERBOSITY} \
		--upload-certs \
		--config ${K8S_KUBEADM_CONFIG} \
		|& tee kubeadm.init_${K8S_INIT_NODE}.log

## join-workers REQUIREs K8S_CA_CERT_HASH captured after init recipe, 
## and then conf-gen and conf-push recipes
join-workers :
	GITOPS_TARGET_LIST=${GITOPS_NODES_WORKER} \
		&& ansibash sudo kubeadm join -v${K8S_VERBOSITY} \
		--config ${K8S_KUBEADM_CONFIG} \
		|& tee kubeadm.join.log

conf-kubectl :
	bash make.recipes.sh conf_kubectl

node nodes :
	ssh ${K8S_INIT_NODE_SSH} kubectl get nodes
