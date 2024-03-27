##############################################################################
## Makefile.settings : Environment Variables for Makefile(s)
include Makefile.settings

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

export PRJ_ROOT   := $(shell pwd)
export LOG_PREFIX := make.$(shell date '+%Y-%m-%dT%H.%M.%Z')

##############################################################################
## Registry

export CNCF_REGISTRY_IMAGE  	?= registry:2.8.3
#export CNCF_REGISTRY_HOST   	 ?= localhost
export CNCF_REGISTRY_HOST   	?= ONXWQBLCS121.entds.ngisn.com
export CNCF_REGISTRY_PORT   	?= 5000
export CNCF_REGISTRY_ENDPOINT 	?= ${CNCF_REGISTRY_HOST}:${CNCF_REGISTRY_PORT}
#export CNCF_REGISTRY_STORE  ?= /home/entds.ngisn.com/4n52626/mnt/registry
export CNCF_REGISTRY_STORE  	?= /tmp/registry


##############################################################################
## Cluster

## HAProxy/Keepalived : 
### VIP within targets' network mask
export HALB_VIP      ?= 10.160.113.234
### EDN Network is segmented (/27; 5 bit mask) so 30 hosts per (user? program?)
export HALB_MASK     ?= 27
### CIDR: 10.160.113.234/27 : IP Range : 224-255 
export HALB_CIDR     ?= ${HALB_VIP}/${HALB_MASK}
export HALB_VIP6     ?= 0:0:0:0:0:ffff:0aa0:7164
export HALB_PORT     ?= 8443
export HALB_DEVICE   ?= ens192
export HALB_FQDN_1   ?= ONXWQBLCS128.entds.ngisn.com
export HALB_FQDN_2   ?= ONXWQBLCS129.entds.ngisn.com
export HALB_FQDN_3   ?= ONXWQBLCS130.entds.ngisn.com

export HALB_ENDPOINT ?= ${HALB_VIP}:${HALB_PORT}

## ansibash 
### Public-key string of ssh user must be in ~/.ssh/authorized_keys of GITOPS_USER at all targets.
#export GITOPS_USER          ?= $(shell id -un)
export GITOPS_USER          ?= gitops
export GITOPS_KEY           ?= ~/.ssh/vm_common
export GITOPS_NODES_MASTER  ?= vm128 vm129 vm130
#export GITOPS_NODES_MASTER  ?= vm130
export GITOPS_NODES_WORKER  ?= 
export GITOPS_TARGET_LIST   ?= ${GITOPS_NODES_MASTER} ${GITOPS_NODES_WORKER}
export GITOPS_SRC_DIR       ?= $(shell pwd)
#export GITOPS_DST_DIR       ?= ${GITOPS_SRC_DIR}
export GITOPS_DST_DIR       ?= /tmp/$(shell basename "${GITOPS_SRC_DIR}")

export ANSIBASH_TARGET_LIST ?= ${GITOPS_TARGET_LIST}
export ANSIBASH_USER        ?= ${GITOPS_USER}

## Configurations : https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/
## K8s RELEASEs https://kubernetes.io/releases/
export K8S_VERSION            ?= 1.29.2
#export K8S_VERSION            ?= 1.28.6
export K8S_PROVISIONER        ?= ${GITOPS_USER}
export K8S_PROVISIONER_KEY    ?= ~/.ssh/vm_common
#export K8S_REGISTRY           ?= registry.k8s.io
export K8S_REGISTRY           ?= ${CNCF_REGISTRY_ENDPOINT}
export K8S_VERBOSITY          ?= 5
export K8S_INIT_NODE_SSH      ?= $(shell echo ${GITOPS_NODES_MASTER} |cut -d' ' -f1)
export K8S_INIT_NODE          ?= ${HALB_FQDN_1}
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
## PKI : These values are overridden by those at Makefile.settings 
### K8S_CERTIFICATE_KEY=$(kubeadm certs certificate-key)
#export K8S_CERTIFICATE_KEY    ?= e7bd0818d8ff317537d2f65ab553a3185f0ddae646dafc224a2e98e873acc4bc
### kubeadm init phase upload-certs --upload-certs ...
export K8S_CERTIFICATE_KEY    ?= 991348057d057866f56feabfb1dfe0f3dd06dc848a2dc79b8c51b1e7cde7a612
### K8S_CA_CERT_HASH="sha256:$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt |openssl rsa -pubin -outform der 2>/dev/null |openssl dgst -sha256 -hex |sed 's/^.* //')"
export K8S_CA_CERT_HASH       ?= sha256:212b51ebc405c032152bd9fe8264d88fd876afc971c247562be8da61d6aec3c2
### K8S_BOOTSTRAP_TOKEN=$(kubeadm token generate)
export K8S_BOOTSTRAP_TOKEN    ?= nmijxk.irqyzts0x5glr2cr

#export K8S_INSTALL_DIR ?= k8s-air-gap-install

##############################################################################
## Recipes : Meta

## K8s on RHEL8 : Air-gap Install (in preferred order)
menu :
	$(INFO) 'K8s on RHEL8 : Air-gap Install (in preferred order)'
	@echo "env          : Print Makefile environment"
	@echo "pki          : Setup this user's PKI at remote provisioner account"
	@echo "pki2         : Same but automated. Requires user having root access sans password"
	@echo "hello        : hostname and user at target(s)"
	@echo "dl           : Download to admin machine all assets; RPMs, binaries, charts, ..."
	@echo "dl-rpms      : Download to admin machine all RPM packages and all their dependencies"
	@echo "dl-bins      : Download to admin machine all non-RPM assets (except container images)"
	@echo "push         : Push this project, ${PWD}, to targets @ /tmp/"
	@echo "prep         : Pre-install tasks"
	@echo "firewalls    : firewalld mods"
	@echo "rpms         : Install all RPM packages"
	@echo "bins         : Install binaries"
	@echo "post         : Configure host, services, and user (${GITOPS_USER})"
	@echo "etcd-test    : Smoke test etcd"
	@echo "============== "
	@echo "lbmake       : Generate HA-LB configurations from .tpl files"
	@echo "lbconf       : Configure HA LB on all control nodes"
	@echo "lbverify     : Verify HA-LB dynamics"
	@echo "============== "
	@echo "imghelm      : Build list of all helm-chart images"
	@echo "imgload      : Load container images into Docker cache"
	@echo "imgreg       : docker run ... a CNCF-distribution registry (${CNCF_REGISTRY_ENDPOINT}) on this machine (local)"
	@echo "imgpush      : Tag and push container images to local registry (${CNCF_REGISTRY_ENDPOINT})"
	@echo "imgcat       : GET /v2/_catalog of local registry (${CNCF_REGISTRY_ENDPOINT})"
	@echo "============== "
	@echo "conf-prep    : Generate cluster PKI (if not exist) at K8S_INIT_NODE; update Makefile.settings"
	@echo "conf-gen     : Generate ${K8S_KUBEADM_CONFIG} from .tpl"
	@echo "conf-push    : Upload ${K8S_KUBEADM_CONFIG} to all nodes"
	@echo "conf-pull    : kubeadm config images pull -v${K8S_VERBOSITY} --config ${K8S_KUBEADM_CONFIG}"
	@echo "init-pre     : kubeadm init phase preflight"
	@echo "============== "
	@echo "init         : kubeadm init ... (${GITOPS_USER}@${K8S_INIT_NODE_SSH})"
	@echo "upload-certs : Re-upload certificates for joining another control-plane node"
	@echo "join-command : Print full join command for a control-plane node (from which we grap token and hash)"
	@echo "join-control : kubeadm join --control-plane ..."
	@echo "join-worker  : kubeadm join ..."
	@echo "conf-kubectl : Make ~/.kube/config"
	@echo "nodes        : kubectl get nodes"
	@echo "kw           : kubectl get pods -o wide (current namespace; see kn)"
	@echo "cilium       : cilium status"


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
	bash foo.sh

#echo ${GITOPS_SRC_DIR}
#echo /tmp/$(shell basename "${GITOPS_SRC_DIR}")

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

# Smoke test this setup
hello :
	ansibash -c 'hostname && id -un && sudo cat /etc/sudoers.d/${GITOPS_USER} || echo ">>> WARNING: Provisioner (${GITOPS_USER}) is not yet configured"'

# Configure the provisioner (GITOPS_USER) on each node. Final task is manual.
# See script for details.
pki :
	printf "%s\n" ${GITOPS_TARGET_LIST} |xargs -I{} scp ${GITOPS_KEY}.pub {}:. 
	printf "%s\n" ${GITOPS_TARGET_LIST} |xargs -I{} scp ${GITOPS_SRC_DIR}/scripts/create_provisioner_target_node.sh {}:. 
	bash ${GITOPS_SRC_DIR}/scripts/create_provisioner_target_node_instruct.sh

# Configure the provisioner (GITOPS_USER) on each node ONLY IF ssh user ($USER) has NOPASSWD set at /etc/sudoers.d/$USER .
pki2 :
	GITOPS_USER=${USER} ANSIBASH_USER=${USER} ansibash -s ${GITOPS_SRC_DIR}/scripts/create_provisioner_target_node.sh '$(shell cat ${GITOPS_KEY}.pub)'

wake :
	ansibash 'sudo killall -s SIGUSR1 automount && sudo mount -a'

dl download :
	${GITOPS_SRC_DIR}/scripts/download-rpms.sh 
	${GITOPS_SRC_DIR}/scripts/download-bins.sh \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.dl.log

dl-rpms :
	${GITOPS_SRC_DIR}/scripts/download-rpms.sh \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.dl-rpms.log

dl-bins :
	${GITOPS_SRC_DIR}/scripts/download-bins.sh \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.dl-bins.log

# No push. Use NFS and identical mount at all target nodes.
push :
	printf "%s\n" ${GITOPS_TARGET_LIST} |xargs -I{} \
		rsync -atuvz --delete --exclude ".git" --exclude "oci-images" -e "ssh -Ti ${GITOPS_KEY}" \
			${GITOPS_SRC_DIR}/ ${GITOPS_USER}@{}:${GITOPS_DST_DIR}/ \
			|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.push.rsync.log
	ansibash -c 'sudo ls -hlrt ${GITOPS_DST_DIR}/scripts' \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.push.ls.log

prep : firewalls 
	ansibash -s ${GITOPS_SRC_DIR}/scripts/hello.sh
	ansibash -s ${GITOPS_SRC_DIR}/scripts/prep-env.sh 
	ansibash sudo dnf -y update 
	ansibash sudo dnf -y makecache

# vip="${HALB_VIP:-192.168.0.100}"
# vip6="${HALB_VIP6:-::ffff:c0a8:64}"
# vport="${HALB_PORT:-8443}"
# device="${HALB_DEVICE:-eth0}" # Network interface common to all LB nodes
# vip="${1}"
# vip6="${2}"
# vport="${3}"
# device="${4}" # Network interface common to all LB nodes

firewalls : 
	ansibash -s ${GITOPS_SRC_DIR}/halb/firewalld-halb.sh ${HALB_VIP} ${HALB_VIP6} ${HALB_PORT} ${HALB_DEVICE} \
		&& ansibash -s ${GITOPS_SRC_DIR}/scripts/firewalld-k8s.sh \
		&& ansibash -s ${GITOPS_SRC_DIR}/scripts/firewalld-istio.sh \
		&& ansibash -s ${GITOPS_SRC_DIR}/scripts/firewalld-cilium.sh \
		&& ansibash sudo firewall-cmd --reload \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.firewalls.log

.PHONY: rpms etcd

rpms install-rpms : 
	ansibash -s ${GITOPS_SRC_DIR}/scripts/install-rpms-air-gap.sh ${GITOPS_DST_DIR}/rpms/rhel8 \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.rpms.install-rpms-air-gap.log

#ansibash -s ${GITOPS_SRC_DIR}/scripts/install-rpms-air-gap.sh ${GITOPS_DST_DIR}/rpms/rhel8

bins install-bins :
	ansibash -s ${GITOPS_SRC_DIR}/scripts/install-containerd-air-gap.sh ${GITOPS_DST_DIR} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.bins.install-containerd-air-gap.log
	ansibash -s ${GITOPS_SRC_DIR}/scripts/install-bins-air-gap.sh ${GITOPS_DST_DIR} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.bins.install-bins-air-gap.log

post : 
	ansibash -s ${GITOPS_SRC_DIR}/scripts/configure-services.sh 
	ansibash -s ${GITOPS_SRC_DIR}/scripts/swap-off.sh 
	ansibash -s ${GITOPS_SRC_DIR}/scripts/selinux-permissive.sh 
	ansibash -s ${GITOPS_SRC_DIR}/scripts/configure-user.sh ${GITOPS_USER}
	rm -f ~/.ssh/master-${GITOPS_USER}*

etcd-test :
	ansibash -s ${GITOPS_SRC_DIR}/scripts/etcd-test.sh \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.etcd-test.log

# etcd-logs :
# 	ansibash sudo journalctl -u etcd.service --no-pager \
# 		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.etcd-logs.log

#ansibash -s ${GITOPS_SRC_DIR}/scripts/install-containerd-air-gap.sh ${GITOPS_DST_DIR}

#################################
# END Air-gap Makefile recipes
# Use Makefile of PRJ root
#################################

#lbclean :
#ansibash -s ${GITOPS_SRC_DIR}/halb/clean-halb.sh ${HALB_VIP} ${HALB_DEVICE}
#ansibash -s ${GITOPS_SRC_DIR}/halb/configure-halb.sh ${HALB_VIP} ${HALB_DEVICE}

#ansibash sudo ip addr del ${HALB_VIP}/24 dev ${HALB_DEVICE}

#bash make.recipes.sh halb
lbmake lbbuild :
	bash ${GITOPS_SRC_DIR}/halb/build-halb.sh
	
#bash halb/push-halb.sh
lbconf :
	scp -p ${GITOPS_SRC_DIR}/halb/keepalived-${HALB_FQDN_1}.conf ${GITOPS_USER}@${HALB_FQDN_1}:keepalived.conf \
		&& scp -p ${GITOPS_SRC_DIR}/halb/keepalived-${HALB_FQDN_2}.conf ${GITOPS_USER}@${HALB_FQDN_2}:keepalived.conf \
		&& scp -p ${GITOPS_SRC_DIR}/halb/keepalived-${HALB_FQDN_3}.conf ${GITOPS_USER}@${HALB_FQDN_3}:keepalived.conf \
		&& ansibash -u ${GITOPS_SRC_DIR}/halb/systemd/99-keepalived.conf \
		&& ansibash -u ${GITOPS_SRC_DIR}/halb/keepalived-check_apiserver.sh \
		&& ansibash -u ${GITOPS_SRC_DIR}/halb/haproxy.cfg \
		&& ansibash -u ${GITOPS_SRC_DIR}/halb/haproxy-rsyslog.conf \
		&& ansibash -u ${GITOPS_SRC_DIR}/halb/etc.hosts \
		&& ansibash -u ${GITOPS_SRC_DIR}/halb/etc.environment \
		&& ansibash -s ${GITOPS_SRC_DIR}/halb/configure-halb.sh ${HALB_CIDR} ${HALB_DEVICE} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.lbconf.log

lbverify : 
	bash ${GITOPS_SRC_DIR}/halb/verify-instruct.sh

lblook :
#ansibash ip -4 -brief addr show dev ${HALB_DEVICE} |grep -e ${HALB_VIP} -e ===
	ansibash ip -4 -brief addr show dev ${HALB_DEVICE} 
	ansibash 'sudo journalctl -eu keepalived |grep -e Entering -e @'

lbfix :	
	ssh gitops@vm124 /bin/bash -s <${GITOPS_SRC_DIR}/halb/firewalld-halb.sh ${HALB_VIP} ${HALB_VIP6} ${HALB_PORT} ${HALB_DEVICE}

imghelm :
	${GITOPS_SRC_DIR}/scripts/oci-images-in-charts.sh \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.imghelm.log
	
# Load images locally (admin node)
imgload : 
	${GITOPS_SRC_DIR}/scripts/oci-images-load.sh \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.imgload.log
	
# Run cncf-distribution registry locally (admin node)
imgreg :
	docker container ps |grep registry \
		|| docker run --rm -d --name registry \
			-v ${CNCF_REGISTRY_STORE}:/var/lib/registry \
			-p ${CNCF_REGISTRY_PORT}:5000 \
			${CNCF_REGISTRY_IMAGE}

imgpush :
	${GITOPS_SRC_DIR}/scripts/oci-images-push-local.sh ${CNCF_REGISTRY_ENDPOINT} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.imgpush.log

imgcat :
	curl -s --noproxy '*' http://${CNCF_REGISTRY_ENDPOINT}/v2/_catalog |jq . 

## Generate cluster PKI (if not exist) and declare kubeadm-relevant params at Makefile.settings 
conf-prep :
	ssh ${GITOPS_USER}@${K8S_INIT_NODE_SSH} /bin/bash -s < \
		${GITOPS_SRC_DIR}/scripts/conf-prep.sh ${K8S_INIT_NODE} ${K8S_KUBEADM_CONFIG} \
		|grep 'export K8S_' |& tee ${GITOPS_SRC_DIR}/scripts/conf-prep
	echo '## @ Makefile.settings : This file is DYNAMICALLY GENERATED  (See Makefile recipes)' \
		|tee Makefile.settings
	cat scripts/conf-prep |tee -a Makefile.settings

conf-gen :
	cat ${GITOPS_SRC_DIR}/kubernetes/${K8S_KUBEADM_CONFIG}.tpl \
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
		|tee ${GITOPS_SRC_DIR}/kubernetes/${K8S_KUBEADM_CONFIG}

conf-push :
	ansibash -u ${GITOPS_SRC_DIR}/kubernetes/${K8S_KUBEADM_CONFIG} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.conf-push.log

conf-pull :
	ansibash sudo kubeadm config images pull -v${K8S_VERBOSITY} \
		--config ${K8S_KUBEADM_CONFIG} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.conf-pull.log

init-pre init-preflight :
	ansibash sudo kubeadm init phase preflight -v${K8S_VERBOSITY} \
		--config ${K8S_KUBEADM_CONFIG} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.init-pre.log

init :
	ssh ${GITOPS_USER}@${K8S_INIT_NODE_SSH} sudo kubeadm init -v${K8S_VERBOSITY} \
		--upload-certs \
		--config ${K8S_KUBEADM_CONFIG} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.init.log

upload-certs : 
	ssh ${GITOPS_USER}@${K8S_INIT_NODE_SSH} sudo kubeadm init phase upload-certs \
		--upload-certs \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.upload-certs.log

join-command :
	ssh ${GITOPS_USER}@${K8S_INIT_NODE_SSH} sudo kubeadm token create \
		--print-join-command \
		--certificate-key ${K8S_CERTIFICATE_KEY} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.print-join-command.log

## TODO : Separate kubeadm-config.yaml for join of control v. worker
## https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-JoinControlPlane
join-control :
	ANSIBASH_TARGET_LIST='${GITOPS_NODES_MASTER}' \
		&& ansibash sudo kubeadm join ${K8S_CONTROL_PLANE_IP}:${K8S_CONTROL_PLANE_PORT} \
			-v${K8S_VERBOSITY} \
			--token ${K8S_BOOTSTRAP_TOKEN} \
			--discovery-token-ca-cert-hash ${K8S_CA_CERT_HASH} \
			--control-plane \
			--certificate-key ${K8S_CERTIFICATE_KEY} \
			--cri-socket ${K8S_CRI_SOCKET} \
			|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.join-control.log


# GITOPS_TARGET_LIST=${GITOPS_NODES_MASTER} \
# 	&& ansibash sudo kubeadm join -v${K8S_VERBOSITY} \
# 		--control-plane \
# 		--config ${K8S_KUBEADM_CONFIG} \
# 		|& tee ${GITOPS_SRC_DIR}/logs/kubeadm.join-control.log

join-worker :
	ANSIBASH_TARGET_LIST="${GITOPS_NODES_WORKER}" \
		&& ansibash sudo kubeadm join -v${K8S_VERBOSITY} \
			--config ${K8S_KUBEADM_CONFIG} \
			|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.join-worker.log

etcd-members :
	ANSIBASH_TARGET_LIST='${GITOPS_NODES_MASTER}' \
		&& ansibash sudo /usr/local/bin/etcdctl member list \
			--endpoints=https://127.0.0.1:2379 \
			--cacert=/etc/kubernetes/pki/etcd/ca.crt \
			--cert=/etc/kubernetes/pki/etcd/server.crt \
			--key=/etc/kubernetes/pki/etcd/server.key \
			|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.etcd-members.log


conf-kubectl :
	bash make.recipes.sh conf_kubectl

node nodes get-nodes :
	ssh ${GITOPS_USER}@${K8S_INIT_NODE_SSH} kubectl get nodes \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.get-nodes.log

kw :
	ssh ${GITOPS_USER}@${K8S_INIT_NODE_SSH} kw \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.kw.log

cilium :
	ssh ${GITOPS_USER}@${K8S_INIT_NODE_SSH} cilium status \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.cilium.status.log

