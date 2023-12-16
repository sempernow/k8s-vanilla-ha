##############################################################################
## Makefile.settings : Environment Variables for Makefile(s)
#include Makefile.settings
##############################################################################
## Environment variable rules:
## - Any TRAILING whitespace KILLS its variable value and may break recipes.
## - ESCAPE only that required by the shell (bash).
## - Environment Hierarchy:
##   - Makefile environment OVERRIDEs OS environment lest set using `?=`.
##  	  - `FOO ?= bar` is overridden by parent setting.
##  	  - `FOO :=`bar` is NOT overridden by parent setting.
##   - Docker YAML `env_file:` OVERRIDEs OS and Makefile environments.
##   - Docker YAML `environment:` OVERRIDEs YAML `env_file:`.
##   - CMDline OVERRIDEs ALL, e.g., `make recipeX FOO=newValue BAR=newToo`.

##############################################################################
## $(INFO) : Usage : `$(INFO) 'What ever'` prints a stylized "@ What ever".
SHELL   := /bin/bash
YELLOW  := "\e[1;33m"
RESTORE := "\e[0m"
INFO    := @bash -c 'printf $(YELLOW);echo "@ $$1";printf $(RESTORE)' MESSAGE

##############################################################################
## Project Meta

export PRJ_ROOT := $(shell pwd)


##############################################################################
## Cluster

## HAProxy/Keepalived : 
export HALB_VIP      ?= 192.168.0.100
export HALB_PORT     ?= 8443
export HALB_ENDPOINT ?= ${HALB_VIP}:${HALB_PORT}

## Configurations : https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/
export K8S_VERSION            ?= 1.28.4
export K8S_VERBOSITY          ?= 5
export K8S_KUBEADM_CONFIG     ?= kubeadm.config.yaml
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

##############################################################################
## Recipes : Meta

menu :
	$(INFO) 'Meta'
	@echo "html      : .MD -> .HTML"
	@echo "push      : gc && git push"
	@echo "config    : Generate ${K8S_KUBEADM_CONFIG} from .tpl"

# $(INFO) 'Environment'
# @echo "PWD=${PRJ_ROOT}"
# @env |grep APP_
# @env |grep _IMAGE |grep -v APP_IMAGE

push :
	gc && echo && git push

html : md2html perms

md2html :
	find . -type f ! -path './.git/*' -iname '*.md' -exec md2html.exe {} \;

perms :
	find . -type f ! -path './.git/*' -exec chmod 0644 "{}" \+
	find . -type f ! -path './.git/*' -iname '*.sh' -exec chmod 0755 "{}" \+

    ##... Each affected file has mtime RESET by `make perms`

##############################################################################
## Recipes : Cluster

config :
	cat ${K8S_KUBEADM_CONFIG}.tpl \
		|sed 's#K8S_VERSION#${K8S_VERSION}#g' \
		|sed 's#K8S_VERBOSITY#${K8S_VERBOSITY}#g' \
		|sed 's#K8S_IMAGE_REPOSITORY#${K8S_IMAGE_REPOSITORY}#g' \
		|sed 's#K8S_CONTROL_PLANE_IP#${K8S_CONTROL_PLANE_IP}#g' \
		|sed 's#K8S_CONTROL_PLANE_PORT#${K8S_CONTROL_PLANE_PORT}#g' \
		|sed 's#K8S_SERVICE_CIDR#${K8S_SERVICE_CIDR}#g' \
		|sed 's#K8S_POD_CIDR#${K8S_POD_CIDR}#g' \
		|sed 's#K8S_CRI_SOCKET#${K8S_CRI_SOCKET}#g' \
		|sed 's#K8S_CGROUP_DRIVER#${K8S_CGROUP_DRIVER}#g' \
		|sed 's#K8S_BOOTSTRAP_TOKEN#${K8S_BOOTSTRAP_TOKEN}#g' \
		|sed 's#K8S_CERTIFICATE_KEY#${K8S_CERTIFICATE_KEY}#g' \
		|sed '/^ *#/d' |sed '/^\s*$$/d' \
		|tee ${K8S_KUBEADM_CONFIG}

