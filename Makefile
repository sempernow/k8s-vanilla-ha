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
export PRJ_ARCH := amd64

##############################################################################
## Cluster

## HAProxy/Keepalived : 
export HALB_VIP      ?= 192.168.0.100
export HALB_VIP6     ?= ::ffff:c0a8:64
export HALB_PORT     ?= 8443
export HALB_DEVICE   ?= eth0
export HALB_FQDN_1   ?= a0.local
export HALB_FQDN_2   ?= a1.local
export HALB_ENDPOINT ?= ${HALB_VIP}:${HALB_PORT}

## ansibash 
export ANSIBASH_NODES_MASTER  ?= a1
export ANSIBASH_NODES_WORKER  ?= a3
export ANSIBASH_TARGET_LIST   ?= ${ANSIBASH_NODES_MASTER} ${ANSIBASH_NODES_WORKER}

## Configurations : https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/
## K8s RELEASEs https://kubernetes.io/releases/
export K8S_VERSION            ?= 1.29.1
#export K8S_VERSION            ?= 1.28.6
export K8S_REGISTRY           ?= registry.k8s.io
export K8S_VERBOSITY          ?= 5
export K8S_INIT_NODE_SSH      ?= $(shell echo ${ANSIBASH_NODES_MASTER} |cut -d' ' -f1)
export K8S_INIT_NODE          ?= ${K8S_INIT_NODE_SSH}.local
export K8S_KUBEADM_CONFIG     ?= kubeadm-config.yaml
export K8S_IMAGE_REPOSITORY   ?= registry.k8s.io
export K8S_CONTROL_PLANE_IP   ?= ${HALB_VIP}
export K8S_CONTROL_PLANE_PORT ?= ${HALB_PORT}
export K8S_SERVICE_CIDR       ?= 10.55.0.0/12
export K8S_POD_CIDR           ?= 10.20.0.0/16
export K8S_CRI_SOCKET         ?= unix:///var/run/containerd/containerd.sock
export K8S_CGROUP_DRIVER      ?= systemd
## K8S_BOOTSTRAP_TOKEN=$(kubeadm token generate)
export K8S_BOOTSTRAP_TOKEN    ?= ojt3kn.5kin2no0pyy554eh
## K8S_CERTIFICATE_KEY=$(kubeadm certs certificate-key)
export K8S_CERTIFICATE_KEY    ?= fb594fa0b1af4fef77045ba76afd3029146557c70677d6f0b447aeac37ffb8ea
## K8S_CA_CERT_HASH="sha256:$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt |openssl rsa -pubin -outform der 2>/dev/null |openssl dgst -sha256 -hex |sed 's/^.* //')"
export K8S_CA_CERT_HASH       ?= sha256:bd55cff35321450ff0fdece0f1b7e3987a96a437dcad866fdf8ff40c1a0e549c 




##############################################################################
## Recipes : Meta

menu :
	$(INFO) 'Meta'
	@echo "html         : .MD to .HTML"
	@echo "push         : gc && git push"
	@echo "conf-gen     : Generate ${K8S_KUBEADM_CONFIG} from .tpl"
	@echo "conf-push    : Upload ${K8S_KUBEADM_CONFIG} to all nodes"
	@echo "conf-pull    : Pull images for subsequent kubeadm init"
	@echo "init-pre     : kubeadm init phase preflight"
	@echo "init         : kubeadm init"
	@echo "join-workers : kubeadm join"
	@echo "conf-kubectl : Make ~/.kube/config"
	@echo "nodes        : kubectl get nodes"
	@echo "lbconf       : Generate HA-LB (HAProxy and Keepalived) conf from .tpl"
	@echo "lbpush       : Push HA-LB configuration to HA-LB nodes"
	@echo "teardown     : Destroy the cluster : kubeadm reset + cleanup at all nodes"

env : 
	$(INFO) 'Environment'
	@echo "PWD=${PRJ_ROOT}"
	@env |grep HALB_ 
	@env |grep K8S_
	@env |grep ANSIBASH_ 

push :
	gc && echo && git push && gl

html : md2html perms

md2html :
	find . -type f ! -path './.git/*' -iname '*.md' -exec md2html.exe {} \;

perms :
	find . -type f ! -path './.git/*' -exec chmod 0644 "{}" \+
	find . -type f ! -path './.git/*' -iname '*.sh' -exec chmod 0755 "{}" \+

    ##... Each affected file has mtime RESET by `make perms`

##############################################################################
## Recipes : Cluster

rpms :
	ANSIBASH_TARGET_LIST=test && ansibash hostname

lbconf halb :
	bash make.recipes.sh halb

lbpush :
	bash halb/push-halb.sh

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
	ANSIBASH_TARGET_LIST=${ANSIBASH_NODES_WORKER} \
		&& ansibash sudo kubeadm join -v${K8S_VERBOSITY} \
		--config ${K8S_KUBEADM_CONFIG} \
		|& tee kubeadm.join.log

conf-kubectl :
	bash make.recipes.sh conf_kubectl

node nodes :
	ssh ${K8S_INIT_NODE_SSH} kubectl get nodes

# To delete all K8s (crictl) images, 
# run with arg : `teardown.sh FLAG_DELETE_IMAGES` 
teardown reset : FORCE
	ansibash -s teardown/teardown.sh |& tee teardown.log

FORCE:
