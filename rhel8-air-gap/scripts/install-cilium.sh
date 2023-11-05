#!/usr/bin/env bash
# https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/
# https://docs.cilium.io/en/stable/operations/system_requirements/

exit 0
######

CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=${PRJ_ARCH:-amd64}

if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# Use CLI to install cilium into cluster
cilium install --version=1.14.1 \
    --helm-set ipam.operator.clusterPoolIPv4PodCIDRList=["10.42.0.0/16"]  \
    --helm-set image.tag=1.14.1


# Requirements : Kernel compile-time options
## See `cat /boot/config-5.14.0-362.18.1.el9_3.x86_64` or `zcat /proc/config.gz`

## Base requirements : Enable
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_NET_CLS_BPF=y
CONFIG_BPF_JIT=y
CONFIG_NET_CLS_ACT=y
CONFIG_NET_SCH_INGRESS=y
CONFIG_CRYPTO_SHA1=y
CONFIG_CRYPTO_USER_API_HASH=y
CONFIG_CGROUPS=y
CONFIG_CGROUP_BPF=y
CONFIG_PERF_EVENTS=y
CONFIG_SCHEDSTATS=y

## L7 + FQDN
CONFIG_NETFILTER_XT_TARGET_TPROXY=m
CONFIG_NETFILTER_XT_TARGET_CT=m
CONFIG_NETFILTER_XT_MATCH_MARK=m
CONFIG_NETFILTER_XT_MATCH_SOCKET=m

## IPsec
CONFIG_XFRM=y
CONFIG_XFRM_OFFLOAD=y
CONFIG_XFRM_STATISTICS=y
CONFIG_XFRM_ALGO=m
CONFIG_XFRM_USER=m
CONFIG_INET{,6}_ESP=m
CONFIG_INET{,6}_IPCOMP=m
CONFIG_INET{,6}_XFRM_TUNNEL=m
CONFIG_INET{,6}_TUNNEL=m
CONFIG_INET_XFRM_MODE_TUNNEL=m
CONFIG_CRYPTO_AEAD=m
CONFIG_CRYPTO_AEAD2=m
CONFIG_CRYPTO_GCM=m
CONFIG_CRYPTO_SEQIV=m
CONFIG_CRYPTO_CBC=m
CONFIG_CRYPTO_HMAC=m
CONFIG_CRYPTO_SHA256=m
CONFIG_CRYPTO_AES=m


## BPF must be mounted 
[[ $(mount |grep /sys/fs/bpf) ]] || {
    # Mount it directly
    #sudo mount bpffs /sys/fs/bpf -t bpf
    # Mount it using /etc/fstab method  
    [[ $(cat /etc/fstab |grep bpffs) ]] || {
        # Append this mount if not exist (idempotent)
        printf "%s\n" 'bpffs                      /sys/fs/bpf             bpf     defaults 0 0'
    }
}

