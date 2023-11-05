# [`k8s-vanilla-ha`](https://github.com/sempernow/k8s-vanilla-ha "GitHub : sempernow/k8s-vanilla-ha") | [Kubernetes.io](https://kubernetes.io/docs/) | [Releases](https://github.com/kubernetes/kubernetes/releases)

Install an on-prem vanilla K8s cluster.
Optionally configured behind an HA load balancer  
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

- Reset hostname
    ```bash
    export ANSIBASH_TARGET_LIST='a0 a1 a3' 
    printf "%s\n" $ANSIBASH_TARGET_LIST |xargs -IX /bin/bash -c '
        ssh $1 sudo hostnamectl set-hostname ${1}.local
    ' _ X
    ```
- Configure for SSH
    - Add target "`IP_ADDR FQDN`" map to local DNS resolver.
    ```bash
    echo $vm_ip $vm_fqdn |sudo tee -a /etc/hosts
    ```
    - Push SSH public key to target.
    ```bash
    hostfprs $vm_fqdn # Scan and list host fingerprint(s) (FPRs)
    # Validate host by matching host-claimed FPR against those scanned,
    # and push key if match.
    ssh-copy-id ~/.ssh/config/vm_common $vm_fqdn 
    ```
    - Add target `Host` entry to `~/.ssh/config`
    ```bash
    vim ~/.ssh/config
    ```
- Configure ssh user for automated/headless `sudo`
    - Create/Mod `/etc/sudoers.d/$USER` file at each target machine.
    ```bash
    line="$USER ALL=(ALL) NOPASSWD: ALL"
    echo "$line" |sudo tee /etc/sudoers.d/$USER
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
sudo yum -y download --arch x86_64 
sudo dnf -y download --arch x86_64 kubectl kubeadm kubelet --resolve --alldeps #... See provisioning scripts

# Install an RPM 
sudo rpm -i $pkg.rpm
# Upgrade if already installed
sudo rpm -U $pkg.rpm

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

## HA Load Balancer : [HAProxy](http://docs.haproxy.org/) + [Keepalived](https://keepalived.org/)

>HAProxy and Keepalived utilize [Virtual Router Redundancy Protocol (VRRP)](https://en.wikipedia.org/wiki/Virtual_Router_Redundancy_Protocol) to implement a **virtual Gateway Router** having an IP address of VIP, and all the control nodes as its clients, load balancing requests to them. Connectivity to the VIP is maintained as long as one or more of its nodes are functioning. Our cluster is built with two such nodes that also function as the cluster's control nodes.

### HA LB : Architecture / Topology

```text
                        kubectl 
                           |
                     keepalived VIP 
                   192.168.0.100:8443
                         (VRRP)
                           |
              -----------------------------
              |                           |
    n0.local: 192.168.0.93      n1.local: 192.168.0.94
    haproxy:                    haproxy:
    - frontend: 8443            - frontend: 8443
    - backend:  6443            - backend:  6443 
```
- VIP is the (highly-available) K8s control-plane endpoint.
    - May also handle data-plane traffic (HTTP/HTTPS) 
      simply by coding more frontend-backend server pairs. 
      See `/etc/haproxy/haproxy.cfg` .
- Regarding the (sub)net in which it operates, 
  select a VIP from any unused IP address in the (sub)net's CIDR,
  and protect it from downstream DHCP assignments.
  E.g., place it outside the DHCP server's client range,
  or add it to the DHCP server's Address Reservation list: 
    - VIP: `192.168.0.100` (Admin selects)
    - MAC: `FE-4D-0F-3B-76-9F` (bogus)
- HAProxy runs on each HA LB (K8s master) node to provide access at `*:8443` for all nodes.
    - HAProxy backend server, listening on port `8443`, 
      forwards traffic in TLS-passthrough mode 
      (AKA "Layer-4 mode" AKA "TCP mode") 
      through its configured frontend server to 
      the upstream server (`kube-apiserver`) listening on port `6443`.
- Keepalived service runs on all control nodes, implementing VRRP to provide `VIP` failover. 
  At any given time, only one node (the current `MASTER`) is set to that `VIP`.
- `kubectl` client connects to this HA endpoint of the K8s control plane (`VIP:8443`).

### HA LB : Install and Configure ([`provision-halb.sh`](halb/provision-halb.sh))

Modify the provisioning script as necessary 
to account for the parameters of your network and nodes.

```bash
pushd halb
./provision-halb.sh
popd
```
- [`haproxy.cfg.tpl`](halb/haproxy.cfg.tpl)
    - `default_server`
        - `inter 10s`: Sets the interval between health checks to 10 seconds.
        - `downinter 5s`: Sets the interval between health checks when a server is considered down to 5 seconds.
    - `rise 2`: The server is considered up after 2 successful health checks.
    - `fall 2`: The server is considered down after 2 failed health checks.
    - `slowstart 60s`: Gradually increases the load sent to a server that just came back up over 60 seconds.
    - `maxconn 250`: Maximum number of concurrent connections allowed to a server.
    - `maxqueue 256`: Maximum number of requests allowed to be queued when the server's `maxconn` is reached.
    - `weight 100`: Sets the weight of the server in load balancing decisions.
    - `check`: Enables health checking.
    - `check-ssl`: Uses SSL for health checks.
    - `verify none`: Disables SSL certificate verification in health checks.
- [`keepalived.conf.tpl`](halb/keepalived.conf.tpl)

### HA LB : Verify/Test/Monitor/Troubleshoot

Verify

```bash
vip='192.168.0.100'
dev=eth0
# Verify connectivity
nc -zvw 2 $vip 8443 
#> "Connection to 192.168.0.100 8443 port [tcp/*] succeeded!"
# Verify HA
ping -4 -D $vip # While running, toggle off each HA (control) node
# Verify VIP added to MASTER node
ansibash ip -4 -brief addr show $dev |grep -e $vip -e ===
```

Test 

```bash
# Ping : prepend timestamp
ping -4 -D $vip  # [1709347772.232527] 64 bytes from 192.168.0.100:... time=0.375 ms
# HTTP GET request
wget --spider -t 1 http://$vip #... connected.
```

Monitor

```bash
# Check state (MASTER||BACKUP) 
ansibash sudo journalctl -eu keepalived |grep -e Entering -e @
# rsyslog of HAProxy
ansibash sudo cat /var/log/haproxy.log
```

Troubleshoot

```bash
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

Mock an upstream at a node running HA-LB

```bash
# Start listener (mock server) as background process
port=6443
socat TCP-LISTEN:$port,fork - &
#... forward to a viable upstream
socat TCP4-LISTEN:6443,fork TCP4:www.google.com:443 &

```

Request to that node

```bash
ip='192.168.0.102'
curl -i --max-time 2 http://$ip:6443/ #> curl: (52) Empty reply from server
```
- The point is that a connection was established; 
  the server (`socat`) responded (with nothing, as expected).

Mock upstream such that it satisfies the vrrp health-check 
script @ `/etc/keepalived/check_apiserver.sh`

```bash
curl --silent --max-time 2 --insecure https://${vip}:6443/
```

### Ensure clean start

```bash
vip='192.168.0.100'
dev='eth0'
sudo ip addr del $vip/24 dev $dev

# Toggle the interface (through which this ssh session runs), exit and reboot
sudo ip link set dev $dev down && sudo shutdown +00:05 -r & && exit

```

## [K8s Cloud Provider Interface (CPI)](https://kubernetes.io/blog/2023/12/14/cloud-provider-integration-changes/)

>The Cloud Provider Interface (CPI) is responsible for running all the platform specific control loops that were previously run in core Kubernetes components under Kubernetes Controller Manager (KCM), which is a daemon that embeds the core control loops shipped with Kubernetes. CPI is moved out-of-tree (K8s `v1.29+`) to allow cloud and infrastructure providers to implement integrations that can be developed, built and released independent of Kubernetes core.

### [keepalived-cloud-provider](https://github.com/munnerz/keepalived-cloud-provider)

### [vSphere CPI](https://cloud-provider-vsphere.sigs.k8s.io/cloud_provider_interface.html#:~:text=The%20Cloud%20Provider%20Interface%20is%20responsible%20for%20running,developed%2C%20built%20and%20released%20independent%20of%20Kubernetes%20core.)

### [K8s Cloud Controller Manager (CCM)](https://kubernetes.io/docs/concepts/architecture/cloud-controller/) | [Develop](https://k8s-docs.netlify.app/en/docs/tasks/administer-cluster/developing-cloud-controller-manager/)

[Getting Started](https://www.techtarget.com/searchCloudComputing/tutorial/Get-started-with-Kubernetes-Cloud-Controller-Manager)


## Cluster Initialization 

### Init programmatically

```bash
export node1=a1
# Idempotent
export K8S_BOOTSTRAP_TOKEN=$(ssh $node1 kubeadm token generate)
export K8S_CERTIFICATE_KEY=$(ssh $node1 kubeadm certs certificate-key)

make conf-gen
make conf-push
make conf-pull
make init-pre
make init
```

#### Details

The cluster is managed as a systemd service by [`kubelet.service`](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/)
). The `kubelet` is configured dynamically by `kubeadm init` and `kubeadm join` at runtime. The command options of `kubelet` can be modified afterward. See `/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf` for more detail.

- On 1st control node:
    - `sudo kubeadm init ...`
- On all other nodes:
    - `sudo kubeadm join ...`
        - With differring command options for 
          workers versus control nodes.

#### [cgroup drivers](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#cgroup-drivers) : `systemd` or `cgroupfs`

On Linux, control groups constrain resources that are allocated to processes.
The `kubelet` and the underlying container runtime need to interface with cgroups to enforce resource management for pods and containers which includes cpu/memory requests and limits for containerized workloads. There are **two versions** of cgroups in Linux: cgroup v1 and cgroup v2. cgroup v2 is the new generation of the cgroup API.

Identify the cgroup version on Linux Nodes

```bash
stat -fc %T /sys/fs/cgroup/
```
- For cgroup v2, the output is `cgroup2fs`.
- For cgroup v1, the output is `tmpfs`.
    - Is v1 @ Hyper-V / AlamLinux 8

~~If cgroup v1, then set `kubelet` flag `--cgroup-driver` to `systemd`, else set to `cgroupfs`.~~
Driver should match the container runtime setting, and if the parent processes are `systemd`, then should use that. 

#### [`kubeadm init`](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/)

```bash
kubeadm init -v 5 --control-plane-endpoint $LOAD_BALANCER_IP:$LOAD_BALANCER_PORT --upload-certs --ignore-preflight-errors=Mem
```
- Certificate Upload: The `--upload-certs` option uploads the certificates and keys generated during the initialization to the `kubeadm-certs` Secret in the `kube-system` namespace. This allows other control-plane nodes to retrieve these certificates and join the cluster as control-plane members. In a high-availability setup, each control-plane node needs access to these certificates to securely communicate with other control-plane nodes. Absent this option, certificates would have to be manually copied to other control-plane nodes. (Those uploaded certs are deleted after 2 hours.)


In our case, on the 1st control-plane node:

```bash
# Pull images
## Delcare registry and K8s version
ver='1.28.5'
reg=registry.k8s.io
conf=kubeadm-config-images.yaml
cat <<EOH |tee $conf
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: $ver
imageRepository: $reg
EOH

export ANSIBASH_TARGET_LIST='a1 a3'

## Pull
ansibash sudo kubeadm config images pull -v5 --config $conf \
    |& tee kubeadm.config.images.pull.log

# Preflight phase only
ansibash sudo kubeadm init phase preflight -v5 \
    --ignore-preflight-errors=Mem \
    |& tee kubeadm.init.phase.preflight.log


# Initialize an HA cluster imperatively : Delete `--dry-run` line when ready.
## All CIDRs are in the Private Address Space (RFC-1918)
ver='1.28.5'
vipp='192.168.0.100:8443'
pnet='10.10.0.0/16'
snet='10.55.0.0/16'
tkn=$(kubeadm token generate)
key=$(kubeadm certs certificate-key)

sudo kubeadm init -v5 --kubernetes-version $ver \
    --token $tkn \
    --certificate-key=$key \
    --upload-certs \
    --ignore-preflight-errors=Mem \
    --control-plane-endpoint "$vipp" \
    --pod-network-cidr "$pnet" \
    --service-cidr "$snet" \
    |& tee kubeadm.init.$(hostname).log

# Configure the client (kubectl)
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
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
- Running `sudo kubeadm init phase preflight` reveals preflight error(s) by name that must be overridden, each error `NAME` having with its own `--ignore-preflight-errors=NAME`, else error must be fixed out-of-band, else `kubeadm init` fails. 
    - In our case, using Hyper-V machines for cluster nodes, its dynamic-memory allocation interfered with `kubeadm init` memory-requirements check, causing initialization failure due to a bogus insufficient-memory finding, reporting error name: "`Mem`".
    ```text
    [preflight] Some fatal errors occurred:
        [ERROR Mem]: the system RAM (844 MB) is less than the minimum 1700 MB
    ```
- All K8s-core pods are Static Pods. Each is assigned the IP address of their node, 
  unlike all other Pods that are created during or after the Pod Network (CIDR) 
  is installed by whatever CNI-compliant network plugin is applied. (Ours is Calico).
  Each Static Pod is managed directly by the `kubelet` running on its node; 
  they are not of the control plane; not stored in etcd.  
    - Location of Static Pod manifests (YAML):  
      `/etc/kubernetes/manifests/`
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

### Join programmatically

>`Makefile` recipe `join-workers` REQUIREs `K8S_CA_CERT_HASH` captured after `init` recipe, and then `conf-gen` and `conf-push` recipes

```bash
export K8S_CA_CERT_HASH="sha256:$(ssh a1 openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt |openssl rsa -pubin -outform der 2>/dev/null |openssl dgst -sha256 -hex |sed 's/^.* //')"

make conf-gen
make conf-push
make join-workers

```

Configure client on all nodes

```bash
make conf-kubectl
```

#### Details

Get the join command:

```bash
kubeadm token create --print-join-command [--config kubeadm.config.yaml]
```

If after reload (subsequent upload) of certificates

```bash
# Generate a NEW join COMMAND for control node (@ certs reload)
## 1. Re upload certificates in the already working master node:
kubeadm init phase upload-certs --upload-certs # Generate a new certificate key.
## 2. Print join command in the already working master node:
kubeadm token create --print-join-command
## 3. Join a new control plane node:
$join_command_from_step_2 --control-plane --certificate-key $key_from_step_1
```

FYI: Can get `--discovery-token-ca-cert-hash` from CA certificate:

```bash
hash="$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt |openssl rsa -pubin -outform der 2>/dev/null |openssl dgst -sha256 -hex |sed 's/^.* //')"

ca_cert_hash="sha256:$hash"

```

@ `a1` (2nd Control node)

```bash
ver='1.28.5'
vipp='192.168.0.100:8443'
pnet='10.10.0.0/16'
snet='10.55.0.0/16'

control_plane_endpoint="$vipp"
bootstrap_token='s7d8yn.lwwhp6jykh6lgll2'
ca_cert_hash='sha256:9de24e925b76e823e6ce5a00068a1c1099417f305065f69a690edc1e578022fb'
certificate_key='c6832d904fa22b7ed75808b04058f539882933287aff002e1ffdafa0e1dd99e2'
vm=a1

## Join control plane
sudo kubeadm join "$control_plane_endpoint" \
    --ignore-preflight-errors=Mem \
    --token $bootstrap_token \
    --discovery-token-ca-cert-hash $ca_cert_hash \
    --control-plane \
    --certificate-key $certificate_key \
    |& tee kubeadm.join.$(hostname).log

sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

```

@ `a3` (Worker)

```bash
# Join worker
sudo kubeadm join "$control_plane_endpoint" \
    --ignore-preflight-errors=Mem \
    --token $bootstrap_token \
    --discovery-token-ca-cert-hash $ca_cert_hash \
    |& tee kubeadm.join.$(hostname).log
```

Configure client at worker node(s) 
using the `kubeconfig` (`~/.kube/config`) of a control node.

```bash
scp a0:/home/u1/.kube/config config
scp config a3:/home/u1/.kube/config
```

FYI, it's okay to mix configuration file with most other flags

```bash
conf=kubeadm-config.yaml
sudo kubeadm join "$control_plane_endpoint" \
    --config $conf \
    --ignore-preflight-errors=Mem \
    --certificate-key $certificate_key
    |& tee kubeadm.join.$(hostname).log
 
```



#### Join @ Control versus Worker node(s)

Install Pod Network addon after cluster initialization (1st control node), 
before adding more nodes.

Join commands in full often require more command flags;
environment-dependent configuration:

```bash
# @ HA-LB configuration
## If set properly during kubeadm init,
## then this endpoint is shown at its join command.
vip_endpoint='192.168.0.100:8443'
api_server_endpoint="$vip_endpoint"

# Join CONTROL node(s) into existing cluster
sudo kubeadm join "$api_server_endpoint" \
    --ignore-preflight-errors=Mem \
    --token $bootstrap_token \
    --discovery-token-ca-cert-hash $caCertHash \
    --control-plane \
    --certificate-key $certKey \
    |& tee kubeadm.join.$(hostname).log

# Join WORKER node(s) into existing cluster
sudo kubeadm join "$api_server_endpoint" \
    --ignore-preflight-errors=Mem \
    --token $bootstrap_token \
    --discovery-token-ca-cert-hash $caCertHash \
    |& tee kubeadm.join.$(hostname).log

```

### `kubeadm` / `kubelet` [Configuration Manifests](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-InitConfiguration)

#### `kubeadm init --config $yaml` 

[kubeadm Configuration (v1beta3)](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/)

All supported `kind:` :

```bash
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
...
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
...
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
...
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
...
```

```bash
conf=kubeadm-config.yaml
kubeadm init -v 5 --config $conf 
```
- [`kubeadm-config.yaml`](kubeadm-config.yaml) ([`.tpl`](kubeadm-config.yaml.tpl))
- Okay to add other commandline flags; mix declarative and imperative.

>*The preferred way to configure `kubeadm` is to pass an YAML configuration file with the `--config` option.* 
>**However, this declarative method is rapidly evolving, and newer versions may be incompatible with older versions.**

Print "defaults". 

```bash
# InitConfiguration, ClusterConfiguration
kubeadm config print init-defaults 
# InitConfiguration, ClusterConfiguration, KubeletConfiguration
kubeadm config print init-defaults --component-configs KubeletConfiguration
# InitConfiguration, ClusterConfiguration, KubeProxyConfiguration
kubeadm config print init-defaults --component-configs KubeProxyConfiguration
```
- These printed parameters are **not set to the actual default values** 
used at runtime. Instead, they are for use as a template from which the configuration(s) may be declared.


### [`kubeadm-config.yaml.tpl`](kubeadm-config.yaml.tpl)

Our template containing all available `kind` of configuration documents.

Generate the YAML ([`kube-config.yaml`](kube-config.yaml)):

```bash

make k8conf
```

Validate the configuration file

```bash
kubeadm config validate --config $conf
```

REFs:
- `kubelet --help` : To list all command options
- `kubeadm init --help` : To list all `init` command options of `kubeadm`
    - [`kind: InitConfiguration`](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta4/#kubeadm-k8s-io-v1beta4-InitConfiguration)
    - [`kind: ClusterConfiguration`] : uploaded to ConfigMap `kubeadm-config` in Namespace `kube-system`. And then read during `kubeadm join`, `kubeadm upgrade`, and `kubeadm reset`.
- `kubeadm join --help` : All The Things (all command options)
    - [`JoinConfiguration`](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta4/#kubeadm-k8s-io-v1beta4-JoinConfiguration)
- [`kubeadm config print --help`](https://pkg.go.dev/k8s.io/kubernetes@v1.28.4/cmd/kubeadm/app/apis/kubeadm/v1beta3) : Whereever configuration is not declared, defaults are used. Their manifests are printed by:
    - `kubeadm config print init-defaults`
    - `kubeadm config print join-defaults`
    - `kubeadm config print reset-defaults`

#### Related configuration files:

See `kubelet.service` `dropin` file for locations 
of both `kubelet` and `kubeadm` configuration files:

```bash
$ cat /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
```

##### Create/Edit `kubelet` config

@ `/etc/systemd/system/kubelet.service.d/10-kubeadm.conf`

```bash
sudo mkdir -p /etc/systemd/system/kubelet.service.d/
suco touch /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
```
`KUBELET_KUBEADM_ARGS="--flag1=value1 --flag2=value2 ..."`

```conf
[Service]
Environment="KUBELET_KUBEADM_ARGS=--network-plugin=calico"
```
- See [kublet-kubeadm integration](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/kubelet-integration/)
- See [`/var/lib/kubelet/kubeadm-flags.env`](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/kubelet-integration/)

After making changes, restart the `kubelet`

```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

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

@ Control node : [`teardown.sh`](teardown.sh)

@ Admin machine (Windows/WSL)

```bash
export ANSIBASH_TARGET_LIST='a0 a1 a2 a3'
ansibash -s teardown/teardown.sh

# Prep for init
ansibash 'sudo reboot'
```

After teardown, the `kubelet.service` will fail. (See `systemctl status kubelet.service`). The journal of systemd logs "`Failed ...`" because `/var/lib/kubelet/config.yaml` file does not exist. (See `sudo jounralctl -ru kubelet.service`).

## Kubernetes Networking

- Node (Host) Network CIDR `192.168.0.0/24`
    - External to cluster.
    - `https://192.168.0.100:8443` (HALB VIP)
        - Load Balancer's IP:PORT is the Control Plane Endpoint; 
          a VIP on the Node (Host) Network.
            - The HAProxy/Keepalived HALB implements VRRP 
              to affect a Virtual Gateway Router whose clients are all the control nodes.
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
- "Service Subnet" AKA "Service CIDR" AKA "Service ClusterIP Range" AKA "Service-Cluster CIDR". 
    Used for internal communication between services within the cluster. 
    It defines the IP address range assigned to Kubernetes services.
    - `10.96.0.0/12` (`kubeadm init` default); *1,048,576 Services*
        - `--service-cidr=$cidr` 
            - @ `kubeadm init`
        - `--service-cluster-ip-range=$cidr`
            - @ `kubelet`, `kube-apiserver`, `etcd`;
              which is initialized on `kubeadm init`
    - Virtual IPs (VIPs) per Service, 
      providing a stable IP address  for all
- "Pod Subnet" AKA "Pod-Network CIDR" AKA "Pod CIDR" AKA "Cluster CIDR"  AKA "Cluster-Network CIDR".
    Defines the IP address range for individual pods within the cluster.
    Pods communicate directly with each other using these IP addresses.
    - `10.244.0.0/16` (`kubeadm init` default); *65,536 Pods*
    - `172.16.0.0/12` (`kubeadm init` default alt); *1,048,576 Pods*
        - Default CIDR is per environment;
          upon Kubernetes' evaluation of the host network.
    - `10.10.0.0/16` (commonly chosen alt) 
        - `--pod-network-cidr=$cidr`
            - @ `kubeadm init`
    - `192.168.0.0/16` (Calico default)
        - WARNING: This overlaps with a common default Node (Host) CIDR.
        - Calico adopts that of `kubeadm init` if set (`--pod-network-cidr`).
        - At other (non-K8s) deployments
            - @ `calico.yaml`
            ```yaml
            - name: CALICO_IPV4POOL_CIDR
              value: "10.10.0.0/16"
            ```

## IP Address Ranges

Cluster-internal CIDRs for Service and Pod networks (subnets) must not overlap. 
Select from within the **Private Address Space** ([RFC-1918](https://www.ietf.org/rfc/rfc1918.txt)):

    RANGE                                               COMMON CIDR

    10.0.0.0    - 10.255.255.255  (10/8 prefix)         10.0.0.0/16
    172.16.0.0  - 172.31.255.255  (172.16/12 prefix)    172.16.0.0/12
    192.168.0.0 - 192.168.255.255 (192.168/16 prefix)   192.168.0.0/24

Note that Static Pods are always asigned the public IP address of their node (host).
Ulike all other Pods, they are handled directly by their node's `kubelet`, 
not by the Kubernetes API (`kube-apiserver`).

### Routing 

Routing rules distinguish between traffic destined for services (handled by `kube-proxy`) 
and traffic between pods (handled by the CNI plugin).

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

## Helm : Install | [Releases](https://github.com/helm/helm/releases)

See [install-helm.sh](rhel/install-helm.sh)

## Install Pod Network 

CNI-compliant NetworkPolicy addon that creates 
and manages the Pod Network AKA Cluster Network.
It accepts the existing Pod Network CIDR if already set, 
else defaults to `192.168.0.0/16`, 
which often conflicts with the subnet CIDR of node(s). 

Popular CNI-compliant Network Addons:

- Cillium is eBPF based, which allows for advanced observability, load balancing, api-aware networking, service-mesh integration, and security.
    - eBPF requires newer distros; is not supported in CentOS/RHEL 7.
- Canal is popular and simple; build of Calico (Policy) and Flannel (overlay).
- Calico is the most popular Network Policy addon

### [Calico : Install by Manifest method](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises#install-calico-with-kubernetes-api-datastore-50-nodes-or-less)

```bash
ver='3.26.4'
manifest='calico.yaml'
wget -nv https://raw.githubusercontent.com/projectcalico/calico/v${ver}/manifests/$manifest
kubectl apply -f $manifest

```
## Install Kubernetes Ingress Controller

Without a 3rd-party Ingress Controller (Pod(s)), K8s Ingress (object) is useless.

### [Istio Ingress Controller](https://istio.io/latest/docs/setup/install/)

This (`istiod`) is a heavyweight addon requiring at least 4GB per node,
and dozens of Linux-kernel modules (some of which don't exist on AlmaLinux 8). 

- [Kernel Module requirements](https://istio.io/latest/docs/setup/platform-setup/prerequisites/#kernel-module-requirements-on-cluster-nodes)
- [Pod requirements](https://istio.io/latest/docs/ops/deployment/requirements/#pod-requirements)
- [Ports](https://istio.io/latest/docs/ops/deployment/requirements/#ports-used-by-istio)

Install using either Helm or Istioctl (Istio Operator is depricated)

Install Istio:

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

```

### [Ingress-NGINX Controller](https://kubernetes.github.io/ingress-nginx/deploy/) | [GitHub](https://github.com/kubernetes/ingress-nginx)

Does NOT include external device (load balancer) necessary for ingress.

[Bare-matal considerations (implementations)](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/)



### [Gateway API](https://github.com/kubernetes-sigs/gateway-api#kubernetes-gateway-api) (K8s-sig)

This is a promising architecture and API from the Kubernetes-sigs group, 
but it's not quite ready for production.

Core Gateway API:

- Gateway
- GatewayClass
- HTTPRoute
- TCPRoute
- TLSRoute
- UDPRoute

Install the Gateway-API CRDs:

```bash
ver='1.0.0'
gateway=gateway-standard-install.yaml
wget -nvO $gateway https://github.com/kubernetes-sigs/gateway-api/releases/download/v${ver}/standard-install.yaml
kubectl apply -f $gateway

```

Then install a 3rd-party implementation &hellip;

#### [Implementations](https://gateway-api.sigs.k8s.io/implementations/#gateways) 

Note those having GA status are the more mature.

- Gateway Controllers 
    - [NGINX Gateway Fabric](https://gateway-api.sigs.k8s.io/implementations/#nginx-gateway-fabric)


## REFerence : K8s core Processes, Pods and containers

### Ephemeral Storage 

The `kubelet` tracks: 

- `emptyDir` volumes, except volumes of `tmpfs`
- Directories holding node-level logs
- Writeable container layers

>The `kubelet` tracks ***only the root filesystem*** for ephemeral storage. OS layouts that mount a separate disk to `/var/lib/kubelet` or `/var/lib/containers` *will not report ephemeral storage correctly*.

### Cluster-level Logging 

Aggregate application logs and store externally so they survive the pod.

#### EFK stack:

- Elasticsearch: This is a highly scalable search and analytics engine. It allows you to store, search, and analyze big volumes of data quickly and in near real-time. In the context of Kubernetes, it is used as the central storage for logs.
- Fluentd: Fluentd is an open-source data collector for unified logging. It is used to collect and send logs from different sources (in this case, the Kubernetes nodes and pods) to Elasticsearch. Fluentd is efficient and flexible, with a lightweight footprint and a pluggable architecture.
- Kibana: Kibana is a visualization layer that works on top of Elasticsearch. It provides a user interface for visualizing and querying the log data stored in Elasticsearch. This makes it easier to perform data analysis, monitor applications, and troubleshoot issues.

#### ELK stack 

Logstash instead of Fluentd for log processing and aggregation. Logstash is more resource-intensive but offers more complex processing capabilities.

#### Loki/Grafana

Newer. Simplest.

### GitOps : CNCF Projects

Argo CD and Flux CD (Flux) are both popular open-source tools used for GitOps in Kubernetes environments. They enable **automated, continuous delivery** (CD) and make it easier to manage deployments and operations **using Git as the source of truth**. Flagger, on the other hand, is a progressive delivery tool often used in conjunction with Flux for implementing advanced deployment strategies like canary releases and A/B testing.

#### Argo CD

- Purpose: Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes, like Flux.
- Key Features:
    - Application Definitions, Configurations, and Environments: All these are declaratively managed and versioned in Git.
    - Automated Deployment: Argo CD automatically applies changes made in the Git repository to the designated Kubernetes clusters.
    - Visualizations and UI: Argo CD provides a rich UI and CLI for viewing the state and history of applications, aiding in troubleshooting and management.
    - Rollbacks and Manual Syncs: Supports rollbacks and manual interventions for syncing with Git repositories.

#### Argo Rollouts
    
Similar to Flagger. It offers advanced deployment strategies like canary and blue/green.


#### Flux CD (Flux) and Flagger

- Flux CD (Flux):
    - Purpose: Flux is primarily a continuous delivery solution that synchronizes a Git repository with a Kubernetes cluster. It ensures that the state of the cluster matches the configuration stored in the Git repository.
    - Key Features: Flux supports automated deployments, where changes to the Git repo trigger updates in the Kubernetes cluster. It also has capabilities for handling secret management and multi-tenancy.
    - Integration with Flagger: Flux can be used together with Flagger for progressive delivery. Flagger extends Flux’s functionality by adding advanced deployment strategies.
- Flagger:
    - Purpose: Flagger is designed for **progressive delivery** techniques like canary releases, A/B testing, and blue/green deployments.
    - Key Features: It automates the release process by gradually shifting traffic to the new version while measuring metrics and running conformance tests. If anomalies are detected, Flagger can automatically rollback.
    - Integration with Service Meshes: Flagger is often used with service meshes like Istio, Linkerd, and others, leveraging their features for traffic shifting and monitoring.

### @ `kubeadm init`

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