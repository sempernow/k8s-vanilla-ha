# [`k8s-vanilla-ha`](https://github.com/sempernow/k8s-vanilla-ha "GitHub : sempernow/k8s-vanilla-ha") | [Kubernetes.io](https://kubernetes.io/docs/) | [Releases](https://github.com/kubernetes/kubernetes/releases)

Install a Vanilla K8s cluster and Calico NetworkPolicy.  
Optionally configure with an external 2-node HA load balancer  
built of HAProxy and Keepalived.

- The HA topology requires at least two load-balancer nodes, 
  which may also be Kubernetes control nodes.
- Tested on 4 Hyper-V VMs running AlmaLinux 8
    - CPU: 2
    - Memory: 2GB
    - Storage: 20GB
    - Network: Eternal (Host)

## Prep the Host(s) OS

Provision and configure all nodes for K8s

### Preliminary Setup

Every target machine must be configured

- Set hostname
    ```bash
    printf "%s\n" $ANSIBASH_TARGET_LIST \
        |xargs -IX /bin/bash -c 'ssh $1 sudo hostnamectl set-hostname $1.local' _ X
    ```
- Configure for ssh 
    - Add target "`IP_ADDR FQDN`" map to local DNS resolver.
    ```bash
    echo $vm_ip $vm_fqdn |sudo tee -a /etc/hosts
    ```
    - Push key to target.
    ```bash
    hostfprs $vm_fqdn # Scan and list host fingerprint(s) (FPRs)
    # Validate host by matching host-claimed FPR against those scanned,
    # and push key if match.
    ssh-copy-id ~/.ssh/config/vm_common $vm_fqdn 
    ```
    - Add target `Host` entry to `~/.ssh/config`.
- Configure ssh user for automated/headless `sudo`
    - Create/Mod `/etc/sudoers.d/$USER` file at each target machine.
    ```bash
    echo "$USER ALL=(ALL) NOPASSWD: ALL" |sudo tee /etc/sudoers.d/$USER
    ```
    ```bash
    # Test
    ssh $vm sudo cat /etc/sudoers
    ```

#### Verify Targets are Configured for Automation

At each machine, attempt to print (`cat`) a file 
that requires elevated privileges to do so.

```bash
ansibash 'sudo cat /etc/sudoers.d/$USER'
```

## Prep : Install/Configure Packages/Tools

```bash
ssh_configured_nodes='a0 a1 a2 a3'

# K8s tools, Docker, containerd
pushd rhel
./provision-k8s-tools.sh $ssh_configured_nodes
popd

# Etcd
pushd etcd
./provision-etcd.sh $ssh_configured_nodes
popd
```
- If VMs are of Hyper-V with dynamic memory, 
then decompose the provisioning script into segments, 
and reboot after each, else FS error on "Out of memory" 
during package install operations.

### @ Air-gap Install : Muster Assets

- Target machines must have 10GB+ @ `/var/local/repos`
- Images must be saved; `docker save ...`
- Target machines must have access to local Docker Registry
  that is loaded with the images.

#### The easy way 

```bash
mkdir k8s-air-gap-install
cd k8s-air-gap-install
sudo kubeadm config images pull |& tee kubeadm.config.images.pull.log
sudo dnf download -y --resolve --alldeps #... See provisioning scripts
```
- Includes dependencies already installed on this box, 
  but attempted install on target does no harm.

#### The hard way

Steps

1. Download/Install all required packages,
and pull all required Docker images 
at any (non-target) administrative machine.
2. Diff the installed RPMs, before versus after K8s-pkgs install,
   and then download the diff list.
3. Run `kubeadm config images pull` 
   to download all required Docker images,
   and then "`docker save`" each to `.tar`.
4. Proceed to next step, but modify the commands 
   regarding RPM package installs 
   to account for those packages being local.

```bash
# List Repos
yum list installed |awk '{ print $3 }' |sort -u |tee repolist.before.txt

# Before : List installed RPM packages
rpm -qa |tee rpm.before.k8s
# install K8s (but don't initialize cluster)
# After : List installed RPM packages
rpm -qa |tee rpm.after.k8s

# Muster all K8s RPMs for air-gap installs
## Generate the list
comm -13 <(sort rpm.before.k8s) <(sort rpm.after.k8s) |tee rpm.k8s
## Download them
$repo='https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/os/Packages'
cat rpm.k8s |xargs -IX wget $repo/X.rpm

sudo kubeadm config images pull |& tee kubeadm.config.images.pull.log

```

### Verify 

```bash
# Environment
export ANSIBASH_TARGET_LIST="a0 a1 a2 a3"

# crictl : List the K8s-core images
ansibash sudo crictl images
# etcd : Read/Write test
pushd etcd
ansibash -s etcd-test.sh
popd
```

Or per node:

```bash
ssh $vm 
ssh $vm COMMAND ARGs
ssh $vm /bin/bash -s < $script
```

## HA Load Balancer | [HAProxy](http://docs.haproxy.org/) | [Keepalived](https://keepalived.org/)

>HAProxy and Keepalived utilize [Virtual Router Redundancy Protocol (VRRP)](https://en.wikipedia.org/wiki/Virtual_Router_Redundancy_Protocol) to implement a virtual Gateway Router having an IP address of VIP, and all the control nodes as its clients, load balancing requests to them. Connectivity to the VIP is maintained as long as one or more of its nodes are functioning. Our cluster is built with two such nodes that also function as the cluster's control nodes.

### LB Architecture

```text
                      kubectl 
                         |
                   keepalived VIP
                 192.168.0.100:8443
              (Virtual Gateway Router)
                         |
            -----------------------------
            |                           |
    a0: 192.168.0.93            a1: 192.168.0.94
    haproxy: 8443               haproxy: 8443        
    kube-apiserver: 6443        kube-apiserver: 6443 
```
- VIP is the (highly-available) K8s control-plane endpoint
- For LAN access, protect VIP from downstream DHCP assignments
  (if VIP address is in the DHCP server's client range)
  by adding the VIP to the DHCP server's Address Reservation list. 
    - VIP: `192.168.0.100` (Admin selects)
    - MAC: `FE-4D-0F-3B-76-9F` (bogus)
- HAProxy runs on each HA LB (K8s master) node to provide access at `*:8443` for all nodes.
- HAProxy forwards incomming traffic (`VIP:8443`) to `kube-apiserver` at control nodes (`*:6443`).
- Keepalived service runs on all control nodes to provide `VIP` address at one of the nodes.
- `kubectl` clients connect to this HA endpoint of the K8s control plane (`VIP:8443`).

### LB Install and Configure ([`provision-ha-lb.sh`](ha-lb/provision-ha-lb.sh))

Modify the provisioning script as necessary 
to account for the parameters of your network and nodes.

```bash
pushd ha-lb
./provision-ha-lb.sh
popd
```

### LB Verify

```bash
# Verify connectivity
nc -zvw 2 $vip 8443 
#> "Connection to 192.168.0.100 8443 port [tcp/*] succeeded!"
# Verify HA
ping -4 $vip # While running, toggle off each HA (control) node
```

### LB Monitor / Troubleshoot

```bash
export ANSIBASH_TARGET_LIST='a0 a1'
# Service (Unit) status
ansibash systemctl status haproxy.service
ansibash systemctl status keepalived.service
# Logs per service (unit)
ansibash journalctl -u $service --since today
# Configuration files
ansibash cat /etc/keepalived/keepalived.conf
ansibash cat /etc/haproxy/haproxy.cfg
```
- Per node (`$vm`) by replacing `ansible` with "`ssh $vm`&hellip;".


## Cluster Initialization 

The cluster is managed as a systemd service by [`kubelet.service`](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/)
). The `kubelet` is configured dynamically by `kubeadm init` and `kubeadm join` at runtime. The command options of `kubelet` can be modified afterward. See `/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf` for more detail.

- On 1st control node:
    - `sudo kubeadm init ...`
- On all other nodes:
    - `sudo kubeadm join ...`
        - With differring command options for 
          workers versus control nodes.

### [cgroup drivers](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#cgroup-drivers) : `systemd` or `cgroupfs`

On Linux, control groups constrain resources that are allocated to processes.
The `kubelet` and the underlying container runtime need to interface with cgroups to enforce resource management for pods and containers which includes cpu/memory requests and limits for containerized workloads. There are **two versions** of cgroups in Linux: cgroup v1 and cgroup v2. cgroup v2 is the new generation of the cgroup API.

Identify the cgroup version on Linux Nodes

```bash
stat -fc %T /sys/fs/cgroup/
```
- For cgroup v2, the output is `cgroup2fs`.
- For cgroup v1, the output is `tmpfs`.

~~If cgroup v1, then set `kubelet` flag `--cgroup-driver` to `systemd`, else set to `cgroupfs`.~~
Should match the container runtime setting, and if the parent processes are `systemd`, then should use that. 

### [`kubeadm init`](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/) | [Configuration](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-InitConfiguration)

>The preferred way to configure `kubeadm` is to pass an YAML configuration file with the `--config` option. Some of the configuration options defined in the [`kubeadm-config.yaml`](rhel/kubeadm-config.yaml) file are also available as command line flags, but only the most common/simple use case are supported with this approach.

~~Map any commandline option "`--foo-bar=val`" to YAML key "`fooBar: val`".~~ Wrong. Can't do that. How to map, and even if they can be mapped, remains an undocumented mystery.

```bash
kubeadm config validate --config kubeadm-config.yaml
kubeadm init --config kubeadm-config.yaml
```

#### `ClusterConfiguration` / `InitConfiguration` @ [`kubeadm-config.yaml`](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta4/)

The configuration file used during `kubeadm init --config ...` [must include a `kind: ClusterConfiguration` document](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/#config-file). It may include all the following documents:

@ `kubeadm-config.yaml`

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
...
--- 
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
...
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
# @ https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration
cgroupDriver: systemd # systemd || cgroupfs
imageGCHighThresholdPercent: 85 # Default
imageGCLowThresholdPercent: 80  # Default
...
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
...
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
...
```

@ `ClusterConfiguration` example

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
#imageRepository: "registry.k8s.io"
kubernetesVersion: "1.28.4"
controlPlaneEndpoint: "192.168.0.100:8443"
networking:
  podSubnet: "10.10.0.0/12"
  serviceSubnet: "10.55.0.0/16"

```

@ `InitConfiguration` example

```yaml
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
imagePullPolicy: IfNotPresent # default
ignorePreflightErrors: ["Mem"]
taints:      # Defaults to control-plane taint for control-plane nodes
#taints: []  # No taints on conrtol-plane nodes if set to empty array; []
localAPIEndpoint:
  advertiseAddress: "192.168.0.100:8443" 
  bindPort: 8443
nodeRegistration:
  # All `kubelet` command options : See kubelet -h |less
  kubeletExtraArgs:
    v: 5           # Verbosity
    image-repository: registry.k8s.io # Default
    upload-certs:  # Expires after 2h (along with join command)
    control-plane-endpoint: 192.168.0.100:8443  # HALB_IP:HALB_PORT 
    pod-cidr:           10.10.0.0/12        # Default is 172.16.0.0/12
    service-cidr:       10.55.0.0/16        # Default is 10.96.0.0/12
    service-dns-domain: cluster.local       # Default
```
- The [`nodeRegistration`](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta4/#kubeadm-k8s-io-v1beta4-NodeRegistrationOptions) subkey "`kubeletExtraArgs: []`" accepts all commandline parameters of "`kubelet`". Map the commandline syntax  "`--foo-bar=val`"  to "`foo-bar: val`" under that subkey.
- `HALB_IP=$(ip -4 addr |grep secondary |awk '{print $2}' |cut -d'/' -f1)`

REFs:
- `kubelet --help` : To list all command options
- `kubeadm init --help` : To list all `init` command options of `kubeadm`
    - [`kind: InitConfiguration`](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta4/#kubeadm-k8s-io-v1beta4-InitConfiguration)
    - [`kind: ClusterConfiguration`] : uploaded to ConfigMap `kubeadm-config` in Namespace `kube-system`. And then read during `kubeadm join`, `kubeadm upgrade`, and `kubeadm reset`.
- `kubeadm join --help` : All The Things (all command options)
    - [`JoinConfiguration`](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta4/#kubeadm-k8s-io-v1beta4-JoinConfiguration)
- [`kubeadm config print --help`](https://pkg.go.dev/k8s.io/kubernetes@v1.28.4/cmd/kubeadm/app/apis/kubeadm/v1beta3) : Whereever configuration is not declared, defaults are used. Their manifests are printed by:
    - `kubeadm config print init-defaults`
        ```yaml
        apiVersion: kubeadm.k8s.io/v1beta3
        kind: InitConfiguration
        bootstrapTokens:
        - groups:
          - system:bootstrappers:kubeadm:default-node-token
          token: abcdef.0123456789abcdef
          ttl: 24h0m0s
          usages:
          - signing
          - authentication
        localAPIEndpoint:
          advertiseAddress: 1.2.3.4
          bindPort: 6443
        nodeRegistration:
          criSocket: unix:///var/run/containerd/containerd.sock
          imagePullPolicy: IfNotPresent
          name: node
          taints: null
        ---
        apiVersion: kubeadm.k8s.io/v1beta3
        kind: ClusterConfiguration
        apiServer:
          timeoutForControlPlane: 4m0s
        certificatesDir: /etc/kubernetes/pki
        clusterName: kubernetes
        controllerManager: {}
        dns: {}
        etcd:
          local:
            dataDir: /var/lib/etcd
        imageRepository: registry.k8s.io
        kubernetesVersion: 1.28.0
        networking:
          dnsDomain: cluster.local
          serviceSubnet: 10.96.0.0/12
        scheduler: {}
        ```
    - `kubeadm config print join-defaults`
        ```yaml
        apiVersion: kubeadm.k8s.io/v1beta3
        kind: JoinConfiguration
        caCertPath: /etc/kubernetes/pki/ca.crt
        discovery:
          bootstrapToken:
            apiServerEndpoint: kube-apiserver:6443
            token: abcdef.0123456789abcdef
            unsafeSkipCAVerification: true
          timeout: 5m0s
          tlsBootstrapToken: abcdef.0123456789abcdef
        nodeRegistration:
          criSocket: unix:///var/run/containerd/containerd.sock
          imagePullPolicy: IfNotPresent
          name: a0.local
          taints: null
        ```
    - `kubeadm config print reset-defaults`
        ```yaml
        apiVersion: kubeadm.k8s.io/v1beta4
        kind: ResetConfiguration
        criSocket: unix:///var/run/containerd/containerd.sock
        certificatesDir: /etc/kubernetes/pki
        ```

### Cluster Init

```bash
kubeadm init -v 5 --control-plane-endpoint $LOAD_BALANCER_IP:$LOAD_BALANCER_PORT --upload-certs --ignore-preflight-errors=Mem
```

>Certificate Upload: The `--upload-certs` option uploads the certificates and keys generated during the initialization to the `kubeadm-certs` Secret in the `kube-system` namespace. This allows other control-plane nodes to retrieve these certificates and join the cluster as control-plane members. In a high-availability setup, each control-plane node needs access to these certificates to securely communicate with other control-plane nodes. Absent this option, certificates would have to be manually copied to other control-plane nodes.

(Those uploaded certs are deleted after 2 hours.)


In our case, on the 1st control-plane node:

```bash
# Pull images beforehand
sudo kubeadm config images pull |& tee kubeadm.config.images.pull.log

# Preflight phase only
sudo kubeadm init phase preflight -v5 \
    --ignore-preflight-errors=Mem \
    |& tee kubeadm.init.phase.preflight.$(hostname).log

# Initialize an HA cluster imperatively : Delete `--dry-run` line when ready.
## All CIDRs are in the Private Address Space (RFC-1918)
vipp='192.168.0.100:8443'
pnet='10.10.0.0/12'
snet='10.55.0.0/16'

sudo kubeadm init -v5 \
    --upload-certs \
    --ignore-preflight-errors=Mem \
    --control-plane-endpoint "$vipp" \
    --pod-network-cidr "$pnet" \
    --service-cidr "$snet" \
    |& tee kubeadm.init.$(hostname).log

# Configure the client (kubectl)
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify
## Status of kubelet.service (systemd unit)
systemctl status kubelet.service

## Make request to kube-apiserver  
## Expect node "NotReady" due to lack of CNI addon 
kubectl get node
# NAME       STATUS     ROLES           AGE   VERSION
# a0.local   NotReady   control-plane   16h   v1.28.3
```
- Certs upload is good for 2hrs. After that, the certs are deleted, 
  and must be regenerated at an existing control node.
    ```bash
    sudo kubeadm init phase upload-certs --upload-certs
    ```
    - Requires a new join command
    ```bash
    sudo kubeadm token create --print-join-command
    ```
- Status of node(s) remains `NotReady` until the "Pod Nework" 
  is configured by installing a CNI-compliant addon such as Calico. 
  Perform such installs at any Master node. See "Install Pod Network" section.

### Cluster-init Verify / Troubleshoot  (Pre CNI addon)

The `kubelet` process is a systemd service.
It spawns all the other core K8s processes,
and communicates with `kube-apiserver`.

```bash
# Re-upload the certs, which last only 2hrs (work from an existing control node)
sudo kubeadm init phase upload-certs --upload-certs
# Print the new join command 
sudo kubeadm token create --print-join-command

# Status of core services
systemctl status kubelet 
systemctl status $unit # Units: kubelet containerd docker
systemctl status $unit 
## Logs of core services
journalctl -u $unit
journalctl -xe |grep kube

## Logs
sudo cat /var/log/messages

## Print all K8s and related processes; commands including options
psk

# Images
sudo crictl images
# Pods running
sudo crictl pods # --state Ready --latest --namespace --label
# Containers running
sudo crictl ps
# Containers all
sudo crictl ps -a

# Config files
cat /etc/kubernetes/admin.config    # Server
cat ~/.kube/config                  # Client
# Manifests of Static Pods
ls -hl /etc/kubernetes/manifests
```
- See `psk`function of [`.bash_functions`](https://github.com/sempernow/home/blob/master/.bash_functions "GitHub/sempernow/home").
- Also re-check HA load balancer status
    - See that section above

### Cluster-init Fix

```bash
# Restart primary service(s)
sudo systemctl restart containerd.service 
sudo systemctl restart kubelet.service

# Last resort : Delete the cluster and start again
sudo kubeadm reset # See "Cluster Teardown"
```


### [`kubelet` config](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration) | [Reference](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/)

The `kubelet.service` is dynamically configured by `kubeadm init|join` at runtime. 
Afterward, its configuration may be modified through the systemd Drop-in direcotry scheme.

REFs: 

- https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/
- https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/#kubelet-conf-d

## Cluster Teardown 

The effect of the "`kubeadm reset`" command 
is to undo that of "`kubeadm init`".  
It also prints info regarding its effects.

It deletes the cluster by stopping all core K8s processes, 
manifests, and data store, purging `etcd`.
Yet the RPM package installations, Docker images and such are unharmed, 
leaving the node (host OS) ready for the next run of "`kubeadm init`". 

```bash
sudo kubeadm cordon $node
sudo kubeadm drain $node
kubectl delete -f calico.yaml
kubectl get deploy -A |xargs -IX -c /bin/bash -c 'kubectl delete ' _ X
sudo kubeadm reset
sudo systemctl disable --now containerd.service
sudo rm -rf /var/lib/containerd/*
sudo rm -rf ~/.kube/*
sudo rm -rf /var/lib/cni
sudo rm -rf /etc/cni
```

@ Admin machine (Windows/WSL)

```bash
# Teardown
## Environment
export ANSIBASH_TARGET_LIST='a0 a1 a2 a3'

## Delete all addons
ansibash 'kubectl delete -f calico.yaml'


## Delete K8s core
ansibash 'sudo kubeadm reset'a
ansibash 'rm -rf ~/.kube/*'

## Verify
ansibash 'ls -hal ~/.kube'
ansibash 'ls -hl /etc/kubernetes/manifests'
ansibash 'psk'
ansibash 'systemctl status kubelet.service'
ansibash 'systemctl status kubelet.service |tail -n 3'

# Prep for init
ansibash 'sudo reboot'
```

## Kubernetes Networking

- Node Network
    - Not under K8s control.
    - `https://192.168.0.100:8443` (HALB VIP)
        - Cluster Address is VIP on (External) Node Network.
            - The HAProxy/Keepalived HALB implements VRRP to affect a virtual gateway router having all the control nodes as its clients.
                - The VIP should lie outside the subnet's DHCP-server range,
                  else a reserved (static) address therein.
        - `sudo cat /etc/kubernetes/admin.conf |yq .clusters.[].cluster.server`
        - `--advertise-address=192.168.0.93`
            - @ `kubelet`, `kube-apiserver`, `etcd`
        - E.g., @ `a0.local`
            ```text
            ☩ ip -4 addr
            ...
            2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> ...
                inet 192.168.0.93/24 brd 192.168.0.255 scope global ... eth0
                ...
                inet 192.168.0.100/24 scope global secondary eth0
                ...
            ```
    - `192.168.0.93` (`a0.local`)
    - `192.168.0.94` (`a1.local`)
- "Service Subnet" AKA "Service CIDR" AKA "Service Cluster-IP Range" AKA "Service-Cluster CIDR" 
    - `10.96.0.0/12` (`kubeadm init` default)
        - `--service-cidr CIDR` 
            - @ `kubeadm init`
        - `--service-cluster-ip-range=10.96.0.0/12`
            - @ `kubelet`, `kube-apiserver`, `etcd`
    - Virtual IPs (VIPs) per Service, 
      providing a stable IP address  for all
- "Pod Subnet" AKA "Pod-Network CIDR" AKA "Pod CIDR" AKA "Cluster CIDR"  AKA "Cluster-Network CIDR"
    - `10.244.0.0/16` (`kubeadm init` default)
    - `172.16.0.0/12` (`kubeadm init` default alt)
    - `10.10.0.0/16` (commonly chosen alt) 
        - `--pod-network-cidr CIDR`
            - Declare @ `kubeadm init`
    - `192.168.0.0/16` (Calico default)
        - Overlaps with a common default Node CIDR.
        - Adopts that of `kubeadm init` if set (`--pod-network-cidr`).
        - At other (non-K8s) deployments, override @ `calico.yaml`
            ```yaml
            - name: CALICO_IPV4POOL_CIDR
              value: "10.10.0.0/16"
            ```

Select from the Private Address Space ([RFC-1918](https://www.ietf.org/rfc/rfc1918.txt)) 
for all cluster-internal CIDRs; for both Service and Pod CIDRs.

         10.0.0.0    - 10.255.255.255  (10/8 prefix)
         172.16.0.0  - 172.31.255.255  (172.16/12 prefix)
         192.168.0.0 - 192.168.255.255 (192.168/16 prefix)

>Failing to explicitly declare Service and Pod CIDRs upon "`kubeadm init`" may result in those CIDRs overlapping with that of the (pre-existing) node network. For example, after one such install, prior to installing Calico, the core pods were assigned IP addresses in the CIDR of the node (in the subnet's DHCP-server range). After Calico install, new pods were assigned IPs in a different (better) CIDR (`172.16.0.0/12`).

### TLS Cipher Suites 

Configuration isssues regarding network admins placing restrictions,
limiting cipher suites to their "allowed" list:

- TLS 1.2
    - An unallowed cipher is mandated for use at HTTP/2 spec (`RFC-7540`).
        - `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256`
        - Unable to disable HTTP/2 using `crypto/tls` pkg, 
          and if able may cause cluster comms problems.
- TLS 1.3 (`RFC-8446`)
    - An unallowed cipher is mandated (with qualifier) for use per spec.
    - Cipher suites for this TLS version are not configurable at either `crypto/tls` pkg 
      or Kubernetes [`KubeletConfiguration.tlsCipherSuites: []`](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration)

REFs:

- [IANA : TLS Parameters](https://www.iana.org/assignments/tls-parameters/tls-parameters.xml)
- HTTP/2 : [RFC-7540](https://www.rfc-editor.org/rfc/rfc7540#section-9.2.2)
- TLS 1.3 : [RFC-8446](https://www.rfc-editor.org/rfc/rfc8446.html#section-9.1)
- [`crypto/tls` (`go1.20.11`)](https://pkg.go.dev/crypto/tls@go1.20.11) 
    - [TLS Cipher Suites @ `crypto/tls`](https://tip.golang.org/blog/tls-cipher-suites)
    - @ TLS 1.3, its cipher suites are [not configurable](https://github.com/golang/go/issues/29349) 
    - [FIPS-verified version](https://stackoverflow.com/questions/68433362/go-dev-boringcrypto-branch-x-crypto-library-fips-140-2-compliance)
        ```text
        The dev.boringcrypto branch of Go replaces the built-in crypto modules with a FIPS-verified version:
        ```
        - [BoringSSL](https://boringssl.googlesource.com/boringssl/)
-  [`kube-apiserver` command options](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
    - @ `/etc/kubernetes/manifests/kube-apiserver.yaml`
    ```yaml
    spec:
    containers:
    - command:
        - kube-apiserver
        ## Default
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        ## Fails to disable HTTP/2.
        #- --feature-gates=AllAlpha=false
        ## TLS settings:
        - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
        - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
        ## Ciphers are not configurable at TLS 1.3 of Golang's crypto/tls package.
        #- --tls-min-version=VersionTLS13 
        #- --tls-cipher-suites=TLS_AES_256_GCM_SHA384
        #...
    ```

## K8s process params : `ps aux` (See `psk`)

## Install Pod Network 

Calico is a CNI-compliant NetworkPolicy addon that creates 
and manages the Pod Network AKA Cluster Network.
It accepts the existing Pod Network CIDR if already set, 
else defaults to `192.168.0.0/16`, 
which often conflicts with the subnet CIDR of node(s). 
So, explicitly declare the Pod Network CIDR on cluster initialization:

```bash
kubeadm init ... --pod-network-cidr "10.10.0.0/16" ...
```

### [Install Calico by Manifest method](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises#install-calico-with-kubernetes-api-datastore-50-nodes-or-less)

```bash
ver='3.26.4'
wget -q https://raw.githubusercontent.com/projectcalico/calico/v${ver}/manifests/calico.yaml
kubectl apply -f calico.yaml

```

## REFerence : K8s core Processes, Pods and containers

>A successful "`kubeadm init ...`" should look like this 
>before the CNI-compatible Pod Network addon is installed.

```bash
☩ ssh a0 kubectl get nodes -o wide
NAME       STATUS     ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                           KERNEL-VERSION                 CONTAINER-RUNTIME
a0.local   NotReady   control-plane   18h   v1.28.3   192.168.0.83   <none>        AlmaLinux 8.8 (Sapphire Caracal)   4.18.0-477.10.1.el8_8.x86_64   containerd://1.6.24

☩ ssh a0 sudo crictl image
IMAGE                                     TAG                 IMAGE ID            SIZE
registry.k8s.io/coredns/coredns           v1.10.1             ead0a4a53df89       16.2MB
registry.k8s.io/etcd                      3.5.9-0             73deb9a3f7025       103MB
registry.k8s.io/kube-apiserver            v1.28.3             5374347291230       34.7MB
registry.k8s.io/kube-controller-manager   v1.28.3             10baa1ca17068       33.4MB
registry.k8s.io/kube-proxy                v1.28.3             bfc896cf80fba       24.6MB
registry.k8s.io/kube-scheduler            v1.28.3             6d1b4fd1b182d       18.8MB
registry.k8s.io/pause                     3.9                 e6f1816883972       322kB

☩ ssh a0 sudo crictl ps
CONTAINER           IMAGE               CREATED             STATE               NAME                      ATTEMPT             POD ID              POD
72d811859581e       6d1b4fd1b182d       About an hour ago   Running             kube-scheduler            9                   65d7192909e91       kube-scheduler-a0.local
4d606ea6c582a       10baa1ca17068       About an hour ago   Running             kube-controller-manager   9                   8977ebc01a183       kube-controller-manager-a0.local
f9f0d1cbabeaa       bfc896cf80fba       18 hours ago        Running             kube-proxy                0                   1613b17736276       kube-proxy-d8hq7
e7ef81dd76787       73deb9a3f7025       18 hours ago        Running             etcd                      8                   dd11363d1cec2       etcd-a0.local
36b84ea53223c       5374347291230       18 hours ago        Running             kube-apiserver            8                   c7133111b7f82       kube-apiserver-a0.local

☩ ssh a0 systemctl status kubelet
● kubelet.service - kubelet: The Kubernetes Node Agent
   Loaded: loaded (/usr/lib/systemd/system/kubelet.service; enabled; vendor preset: disabled)
  Drop-In: /usr/lib/systemd/system/kubelet.service.d
           └─10-kubeadm.conf
   Active: active (running) since Sat 2023-11-11 01:19:08 EST; 18h ago
     Docs: https://kubernetes.io/docs/
 Main PID: 7321 (kubelet)
    Tasks: 13 (limit: 10714)
   Memory: 132.9M
   CGroup: /system.slice/kubelet.service
           └─7321 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.9

Nov 11 19:19:23 a0.local kubelet[7321]: E1111 19:19:23.250596    7321 kubelet.go:2855] "Container runtime network not ready" networkReady="NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized"
Nov 11 19:19:28 a0.local kubelet[7321]: E1111 19:19:28.251590    7321 kubelet.go:2855] "Container runtime network not ready" networkReady="NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized"
# ... repeated every 5 seconds

☩ ssh a0 systemctl status docker
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; vendor preset: disabled)
   Active: active (running) since Sat 2023-11-11 00:58:10 EST; 18h ago
     Docs: https://docs.docker.com
 Main PID: 1041 (dockerd)
    Tasks: 9
   Memory: 44.0M
   CGroup: /system.slice/docker.service
           └─1041 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock

Warning: Journal has been rotated since unit was started. Log output is incomplete or unavailable.

☩ ssh a0 systemctl status containerd
● containerd.service - containerd container runtime
   Loaded: loaded (/usr/lib/systemd/system/containerd.service; enabled; vendor preset: disabled)
   Active: active (running) since Sat 2023-11-11 01:11:09 EST; 18h ago
     Docs: https://containerd.io
 Main PID: 6276 (containerd)
    Tasks: 76
   Memory: 126.4M
   CGroup: /system.slice/containerd.service
           ├─6276 /usr/bin/containerd
           ├─6882 /usr/bin/containerd-shim-runc-v2 -namespace k8s.io -id c7133111b7f82dfc25e3053cb2bf620f72b837cd900419831ef7467937746e4e -address /run/containerd/containerd.sock
           ├─6909 /usr/bin/containerd-shim-runc-v2 -namespace k8s.io -id 8977ebc01a1835aad8052d3f74efd84669b8a0f1f0671f7338ec987e73643f45 -address /run/containerd/containerd.sock
           ├─6946 /usr/bin/containerd-shim-runc-v2 -namespace k8s.io -id dd11363d1cec2d0a5a2eba59795489445dfbdcb9d968198b2b5f4c2e7e9b3b30 -address /run/containerd/containerd.sock
           ├─6970 /usr/bin/containerd-shim-runc-v2 -namespace k8s.io -id 65d7192909e91d84e76c6030a982ab54f0b7a54581d71b58987baf469bafaeea -address /run/containerd/containerd.sock
           └─7353 /usr/bin/containerd-shim-runc-v2 -namespace k8s.io -id 1613b17736276644a6b8735eeb16e886d8ccd48bf5886f73d4305682fc4b7191 -address /run/containerd/containerd.sock

Nov 11 17:47:52 a0.local containerd[6276]: time="2023-11-11T17:47:52.920080462-05:00" level=info msg="RemoveContainer for \"f204c6ad7a53e6a5c5a8027b269f056b71cd068ab8a46d8a3059e381fb85a1c9\""
Nov 11 17:47:52 a0.local containerd[6276]: time="2023-11-11T17:47:52.925746998-05:00" level=info msg="RemoveContainer for \"f204c6ad7a53e6a5c5a8027b269f056b71cd068ab8a46d8a3059e381fb85a1c9\" returns successfully"
Nov 11 17:48:11 a0.local containerd[6276]: time="2023-11-11T17:48:11.912410311-05:00" level=info msg="CreateContainer within sandbox \"8977ebc01a1835aad8052d3f74efd84669b8a0f1f0671f7338ec987e73643f45\" for container &ContainerMetadata{Name:kube-controller-manager,Attempt:9,}"
Nov 11 17:48:11 a0.local containerd[6276]: time="2023-11-11T17:48:11.939738749-05:00" level=info msg="CreateContainer within sandbox \"8977ebc01a1835aad8052d3f74efd84669b8a0f1f0671f7338ec987e73643f45\" for &ContainerMetadata{Name:kube-controller-manager,Attempt:9,} returns container id \"4d606ea6c582a29fba80579f108e45430a27848d54d72065b47e2efbd3778503\""
Nov 11 17:48:11 a0.local containerd[6276]: time="2023-11-11T17:48:11.940123665-05:00" level=info msg="StartContainer for \"4d606ea6c582a29fba80579f108e45430a27848d54d72065b47e2efbd3778503\""
Nov 11 17:48:12 a0.local containerd[6276]: time="2023-11-11T17:48:12.010394991-05:00" level=info msg="StartContainer for \"4d606ea6c582a29fba80579f108e45430a27848d54d72065b47e2efbd3778503\" returns successfully"
Nov 11 17:48:13 a0.local containerd[6276]: time="2023-11-11T17:48:13.912098969-05:00" level=info msg="CreateContainer within sandbox \"65d7192909e91d84e76c6030a982ab54f0b7a54581d71b58987baf469bafaeea\" for container &ContainerMetadata{Name:kube-scheduler,Attempt:9,}"
Nov 11 17:48:13 a0.local containerd[6276]: time="2023-11-11T17:48:13.985540326-05:00" level=info msg="CreateContainer within sandbox \"65d7192909e91d84e76c6030a982ab54f0b7a54581d71b58987baf469bafaeea\" for &ContainerMetadata{Name:kube-scheduler,Attempt:9,} returns container id \"72d811859581e150353cf3a98d3f6657e5f07988e95096f57f93a2e4b1451e02\""
Nov 11 17:48:13 a0.local containerd[6276]: time="2023-11-11T17:48:13.986381461-05:00" level=info msg="StartContainer for \"72d811859581e150353cf3a98d3f6657e5f07988e95096f57f93a2e4b1451e02\""
Nov 11 17:48:14 a0.local containerd[6276]: time="2023-11-11T17:48:14.078895713-05:00" level=info msg="StartContainer for \"72d811859581e150353cf3a98d3f6657e5f07988e95096f57f93a2e4b1451e02\" returns successfully"

☩ ssh a0 /bin/bash -s < rhel/psk.sh
@ containerd
--containerd=/run/containerd/containerd.sock
--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf
--kubeconfig=/etc/kubernetes/kubelet.conf
--config=/var/lib/kubelet/config.yaml
--container-runtime-endpoint=unix:///var/run/containerd/containerd.sock
--pod-infra-container-image=registry.k8s.io/pause:3.9
--
@ docker
--containerd=/run/containerd/containerd.sock
--
@ etcd
--advertise-address=192.168.0.83
--allow-privileged=true
--authorization-mode=Node,RBAC
--client-ca-file=/etc/kubernetes/pki/ca.crt
--enable-admission-plugins=NodeRestriction
--enable-bootstrap-token-auth=true
--etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
--etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
--etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
--etcd-servers=https://127.0.0.1:2379
--kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
--kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
--proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
--proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
--requestheader-allowed-names=front-proxy-client
--requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
--requestheader-extra-headers-prefix=X-Remote-Extra-
--requestheader-group-headers=X-Remote-Group
--requestheader-username-headers=X-Remote-User
--secure-port=6443
--service-account-issuer=https://kubernetes.default.svc.cluster.local
--service-account-key-file=/etc/kubernetes/pki/sa.pub
--service-account-signing-key-file=/etc/kubernetes/pki/sa.key
--service-cluster-ip-range=10.96.0.0/12
--tls-cert-file=/etc/kubernetes/pki/apiserver.crt
--tls-private-key-file=/etc/kubernetes/pki/apiserver.key
--advertise-client-urls=https://192.168.0.83:2379
--cert-file=/etc/kubernetes/pki/etcd/server.crt
--client-cert-auth=true
--data-dir=/var/lib/etcd
--experimental-initial-corrupt-check=true
--experimental-watch-progress-notify-interval=5s
--initial-advertise-peer-urls=https://192.168.0.83:2380
--initial-cluster=a0.local=https://192.168.0.83:2380
--key-file=/etc/kubernetes/pki/etcd/server.key
--listen-client-urls=https://127.0.0.1:2379,https://192.168.0.83:2379
--listen-metrics-urls=http://127.0.0.1:2381
--listen-peer-urls=https://192.168.0.83:2380
--name=a0.local
--peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt
--peer-client-cert-auth=true
--peer-key-file=/etc/kubernetes/pki/etcd/peer.key
--peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
--snapshot-count=10000
--trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
--
@ kubelet
--advertise-address=192.168.0.83
--allow-privileged=true
--authorization-mode=Node,RBAC
--client-ca-file=/etc/kubernetes/pki/ca.crt
--enable-admission-plugins=NodeRestriction
--enable-bootstrap-token-auth=true
--etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
--etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
--etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
--etcd-servers=https://127.0.0.1:2379
--kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
--kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
--proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
--proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
--requestheader-allowed-names=front-proxy-client
--requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
--requestheader-extra-headers-prefix=X-Remote-Extra-
--requestheader-group-headers=X-Remote-Group
--requestheader-username-headers=X-Remote-User
--secure-port=6443
--service-account-issuer=https://kubernetes.default.svc.cluster.local
--service-account-key-file=/etc/kubernetes/pki/sa.pub
--service-account-signing-key-file=/etc/kubernetes/pki/sa.key
--service-cluster-ip-range=10.96.0.0/12
--tls-cert-file=/etc/kubernetes/pki/apiserver.crt
--tls-private-key-file=/etc/kubernetes/pki/apiserver.key
--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf
--kubeconfig=/etc/kubernetes/kubelet.conf
--config=/var/lib/kubelet/config.yaml
--container-runtime-endpoint=unix:///var/run/containerd/containerd.sock
--pod-infra-container-image=registry.k8s.io/pause:3.9
--
@ kube-apiserver
--advertise-address=192.168.0.83
--allow-privileged=true
--authorization-mode=Node,RBAC
--client-ca-file=/etc/kubernetes/pki/ca.crt
--enable-admission-plugins=NodeRestriction
--enable-bootstrap-token-auth=true
--etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
--etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
--etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
--etcd-servers=https://127.0.0.1:2379
--kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
--kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
--proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
--proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
--requestheader-allowed-names=front-proxy-client
--requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
--requestheader-extra-headers-prefix=X-Remote-Extra-
--requestheader-group-headers=X-Remote-Group
--requestheader-username-headers=X-Remote-User
--secure-port=6443
--service-account-issuer=https://kubernetes.default.svc.cluster.local
--service-account-key-file=/etc/kubernetes/pki/sa.pub
--service-account-signing-key-file=/etc/kubernetes/pki/sa.key
--service-cluster-ip-range=10.96.0.0/12
--tls-cert-file=/etc/kubernetes/pki/apiserver.crt
--tls-private-key-file=/etc/kubernetes/pki/apiserver.key
@ kube-controller-manager
--authentication-kubeconfig=/etc/kubernetes/controller-manager.conf
--authorization-kubeconfig=/etc/kubernetes/controller-manager.conf
--bind-address=127.0.0.1
--client-ca-file=/etc/kubernetes/pki/ca.crt
--cluster-name=kubernetes
--cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt
--cluster-signing-key-file=/etc/kubernetes/pki/ca.key
--controllers=*,bootstrapsigner,tokencleaner
--kubeconfig=/etc/kubernetes/controller-manager.conf
--leader-elect=true
--requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
--root-ca-file=/etc/kubernetes/pki/ca.crt
--service-account-private-key-file=/etc/kubernetes/pki/sa.key
--use-service-account-credentials=true
--
@ kube-scheduler
--authentication-kubeconfig=/etc/kubernetes/scheduler.conf
--authorization-kubeconfig=/etc/kubernetes/scheduler.conf
--bind-address=127.0.0.1
--kubeconfig=/etc/kubernetes/scheduler.conf
--leader-elect=true
--
@ kube-proxy
--config=/var/lib/kube-proxy/config.conf
--hostname-override=a0.local
--

```

@ `/etc/kubernetes/admin.json` || `~/.kube/config`

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0...S0K
    server: https://192.168.0.100:8443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes-admin
  user:
    client-certificate-data: LS0...tCg==
    client-key-data: LS0...LQo=
```