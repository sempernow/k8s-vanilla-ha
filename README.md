# [Kubernetes.io](https://kubernetes.io/docs/)

Install a Vanilla K8s cluster and Calico for Pod Network (Network Policy. Optionally configure with an external HA Load Balancer built of HAProxy and Keepalived.

- The HA topology requires at least two control-plane nodes.
- Tested on 4 Hyper-V VMs running AlmaLinux 8
    - CPU: 1
    - Memory: 2GB
    - Storage: 20GB
    - Network: Eternal (Host)

## Prep

Provision and configure all nodes for K8s

### Install and Configure

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

### Test `etcd`

```bash
export ANSIBASH_TARGET_LIST="$ssh_configured_nodes"
pushd etcd
ansibash -s etcd-test.sh
popd
```

Or per node:

```bash
pushd etcd
ssh $vm /bin/bash -s <etcd-test.sh
popd
```

### HA Load Balancer | [HAProxy](http://docs.haproxy.org/) | [Keepalived](https://keepalived.org/)

>HAProxy and Keepalived are based on Virtual Router Redundancy Protocol (VRRP) that allows all HA-LB nodes to share one virtual IP address (VIP). Connectivity to the VIP is maintained as long as one or more HA-LB nodes are functioning. Our cluster is built with two such nodes that also function as the cluster's control nodes.

#### Architecture

```text
                      kubectl 
                         |
                   keepalived VIP
                 192.168.0.100:8443
                         |
            -----------------------------
            |                           |
    a0: 192.168.0.83            a1: 192.168.0.87
    haproxy: 8443               haproxy: 8443        
    kube-apiserver: 6443        kube-apiserver: 6443 
```
- VIP is the HA K8s Control Plane Endpoint.
- For LAN access, protect VIP from gateway router's dynamic assignments
(if VIP is in that client range of DHCP server)
by adding the VIP to router's DHCP Address Reservation list. 
    - VIP: `192.168.0.100` (Admin selects)
    - MAC: `FE-4D-0F-3B-76-9F` (bogus)
- HAProxy runs on each HA LB (K8s master) node to provide access at `*:8443` for all nodes.
- HAProxy forwards incomming traffic (`VIP:8443`) to `kube-apiserver` at control nodes (`*:6443`).
- Keepalived service runs on all control nodes to provide `VIP` address at one of the nodes.
- `kubectl` clients connect to this HA endpoint of the K8s control plane (`VIP:8443`).

#### Install and Configure ([`provision-ha-lb.sh`](ha-lb/provision-ha-lb.sh))

Modify the provisioning script as necessary 
to account for the parameters of your network and nodes.

```bash
pushd ha-lb
./provision-ha-lb.sh
popd
```

#### Verify

```bash
# Verify connectivity
nc -zv $vip 8443 
#> "Connection to 192.168.0.100 8443 port [tcp/*] succeeded!"
# Verify HA
ping -4 $vip # While running, toggle off each HA (control) node
```

#### Monitor / Troubleshoot

```bash
ansibash journalctl -u $service --since today
ansibash systemctl status haproxy.service
ansibash systemctl status keepalived.service
```
- Either "`ansibash ...`", or per node using "`ssh $vm ...`".


## Initialize Cluster : [`kubeadm init`](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/)

>Certificate Upload: The `--upload-certs` option uploads the certificates and keys generated during the initialization to the `kubeadm-certs` Secret in the `kube-system` namespace. This allows other control-plane nodes to retrieve these certificates and join the cluster as control-plane members. In a high-availability setup, each control-plane node needs access to these certificates to securely communicate with other control-plane nodes. Absent this option, certificates would have to be manually copied to other control-plane nodes.

```bash
kubeadm init --control-plane-endpoint $LOAD_BALANCER_IP:$LOAD_BALANCER_PORT --upload-certs
```

In our case, on the 1st control-plane node:

```bash
vip='192.168.0.100'
kubeadm init --control-plane-endpoint "$vip:8443" --upload-certs
```
1. Note the printed instructions.
1. Configure the client (`kubectl`) 
  by copying the server config (`admin.conf`).
1. Install Calico, working from this node. 
   This regards the "deploy a pod network" instruction noted above.
    - How-to is WIP ([`install-calico.sh`](rhel/install-calico.sh)). 
    The CKA method is dated:
    ```bash
    # CKA Method
    kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
    ```