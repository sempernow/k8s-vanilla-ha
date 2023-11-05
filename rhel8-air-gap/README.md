# ['N52626/k8s-air-gap-install'](https://github.northgrum.com/N52626/k8s-air-gap-install "github.northgrum.com")

>This project automates an air-gap install of vanilla K8s + external HA LB 
>onto three VMs of RHEL 8.9 that have no access to EPEL repo and perhaps dated base repos.

# Doings 

Scripted : See `Makefile` recipes

# Plans ...

## Phases and Order

### Prep

- Install Ansible on admin node (not a cluster node)
- Prepare all target machines by running this script on each one. 
  It requires `root` privileges.
    - [`create_provisioner_target_node.sh`](scripts/create_provisioner_target_node.sh)


### Provision

- Push all assets to each machine
- Install binaries
- Install RPMs

### Configure Hosts

- Kernel
- FS
- Network 
- Firewall

### Configure External Load Balancer

- HALB @ control node(s)

### Build Cluster 

- Initialize
- Configure
- Join


## Prep all target machines

@ target machines

```bash
# Create the provisioner user
u=ansible
sudo adduser $u
sudo passwd $u
sudo groupadd $u

# Create/Mod /etc/sudoers.d/$USER file at each target machine.
echo "$u ALL=(ALL) NOPASSWD: ALL" |sudo tee /etc/sudoers.d/$u

```

@ admin machine

```bash
host=10.160.113.243
hostfprs $host # Scan and list host fingerprint(s) (FPRs)
# Validate host by matching host-claimed FPR against those scanned,
# and push key if match.
ssh-copy-id ~/.ssh/config/vm_common $u1@$host
# Add entry for $u@$host
vim ~/.ssh/config
# Test 
ssh $u@$host sudo ls -hl /etc/sudoers.d/

```

## Download RPMs

To prepare for air-gap provisioning of VMs.

```bash
# Update else stale version of repo is downloaded
sudo dnf -y update # Important !!!

# All packages of this list are provided by either BaseOS or AppStream repos
list='make gcc mkisofs iproute-tc bash-completion bind-utils tar nc socat lsof wget curl git httpd httpd-tools jq vim tree'
try='--nobest --allowerasing'
rpms=rpms # Folder containing the downloaded RPM(s)
mkdir -p $rpms;cd $rpms

# Optionally log pkg names/repos list
pkg_info=dnf.provides.list.log
sudo dnf provides $list |tee $pkg_info
cat $pkg_info |grep Repo |sort -u 

# Download all rpms listed and their recursive dependencies (135MB of 253 rpm files)
printf "%s\n" $list |xargs -IX /bin/bash -c '
        echo "=== @ $1"
        sudo dnf -y download --alldeps --resolve $1 \
            || sudo dnf -y download $0 --alldeps --resolve $1
    ' "$try" X |& tee rpms.download.log

# Simpler and has same effect, but probably lots of redundant-download attempts
sudo dnf -y download --alldeps --resolve $list || sudo dnf -y download $try --alldeps --resolve $list

# Sans dependencies
printf "%s\n" $list |xargs -IX /bin/bash -c '
        echo "=== @ $1"
        sudo dnf -y download $1 \
            || sudo dnf -y download $0 $1
    ' "$try" X |& tee rpms.download.log

```
- Most dependencies are redundant, 
  often installed by prior installs,
  so store dependencies in a common folder,
  and install those (whenever) first.

## Install pkg(s) from RPM file(s)

```bash
rpms=rpms # Folder containing all downloaded RPM(s)
try='--nobest --allowerasing'
find $rpms -type f -iname '*.rpm' -exec /bin/bash -c '
        echo "=== @ $1"
        sudo dnf -y install $1 \
            || sudo dnf -y install $0 $1
    ' "$try" {} \; |& tee rpms.install.log

# Simpler and has same effect, but probably lots of redundant-install attempts
sudo dnf -y install $list || sudo dnf -y install $try $list
```

### Install EPEL Repo

>The public EPEL repo has an installable package.   
>Not all repos do. 

```bash
# Update else stale version of repo is downloaded
sudo dnf -y update # Important !!!
pkg=epel-release
sudo dnf -y install $pkg
# Verify
dnf repolist
```

## Make ISO of repo | [`make_repo_iso.sh`](make_repo_iso.sh)

Repo ISOs are used by hypervisors along with an OS golden image, 
especially in restricted-network environments.

### UPDATE: use "`dnf reposync ...`" method

```bash
# Update else stale version of repo is downloaded
sudo dnf -y update # Important !!!

mkdir -p repos;pushd repos

# Install tools
sudo dnf -y install dnf-plugins-core createrepo_c genisoimage

# FYI: Public EPEL repoid is "epel" and is ~ 17GB. This one is ~ 47GB
id='EDN_EPEL9_EPEL9' 

# Download repo and meta
sudo dnf reposync --gpgcheck --repoid=$id --download-path=$(pwd) --downloadcomps --downloadonly --download-metadata

# Create repo
sudo createrepo_c $id

# Make ISO
genisoimage -o $id.iso -R -J -joliet-long $id
```

REF 

```bash
dnf config-manager --dump # See all settings
# If install fails due to (false) GPG key problems, ... 
sudo dnf -y install --nogpgcheck $pkg 

# Test for installed package (when not of a binary name)
rpm -q --quiet $pkg || echo "$pkg is NOT installed" 
## or
[[ $(dnf list --installed $pkg 2>&1 |grep $pkg) ]] \
    || echo "$pkg is NOT installed" 
```

### Mount ISO

```bash
id='EDN_EPEL9_EPEL9'
mnt=/mnt/$id
sudo mkdir -p $mnt
sudo mount -t iso9660 $id.iso $mnt

```

### Verify ISO content

```bash
$ ll $mnt
total 164K
drwxr-xr-x.  2 user1 group1 4.0K 2024-01-30 15:40 repodata
drwxr-xr-x. 29 user1 group1 4.0K 2024-01-30 15:40 Packages
-rwxr-xr-x.  1 user1 group1 127K 2024-01-30 15:40 comps.xml
```

### Prior

This direct reposync method is more aligned with yum; pre dnf.

```bash
# Create a repo (including its metadata)
dir='repos';mkdir -p $dir;cd $dir
reposync --gpgcheck --repoid=$id --download-path=$(pwd) --downloadcomps --downloadonly --download-metadata
# Create repo metadata
#createrepo . 
#... Metadata (./repodata) already created by reposync 
```

```bash
dir=$id # Created by reposync (above)
mkisofs -o $dir.iso -J -joliet-long -R -v $dir
```

### Mount ISO

```bash
mnt='/mnt/epel'
sudo mkdir -p $mnt
sudo mount -t iso9660 $dir.iso $mnt

```

### Verify ISO content

```bash
$ ll $mnt
total 164K
drwxr-xr-x.  2 user1 group1 4.0K 2024-01-30 15:40 repodata
drwxr-xr-x. 29 user1 group1 4.0K 2024-01-30 15:40 Packages
-rwxr-xr-x.  1 user1 group1  29K 2024-01-30 15:40 metalink.xml
-rwxr-xr-x.  1 user1 group1 127K 2024-01-30 15:40 comps.xml
```
- File `metalink.xml` does not exist if using the `dnf` method.


## CNCF Distribution Registry 

### [Deploy a local Docker Registry](https://distribution.github.io/distribution/about/deploying/)

```bash
# Run the CNCF Distribution registry
img='registry:2.8.3'
docker run --rm -d -p 5000:5000 --name registry $img
#... flag: --restart=always, versus --rm, is not reliable.

# +Bind mount to declared (custom) host-storage location
docker run --rm -d -p 5000:5000 --name registry \
    -v $host_path:/var/lib/registry \
    $img

# +TLS 
docker run --rm -d -p 5000:5000 --name registry \
    -v $host_path_to_images:/var/lib/registry \
    -v $host_path_to_certs:/certs \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
    -p 443:443 \
    $img

# +HTTP Basic Auth via Apache server (httpd)
docker run --entrypoint htpasswd httpd:2 -Bbn $user $pw > $host_path_to_auth/htpasswd
docker run --rm -d -p 5000:5000 --name registry \
    -v $host_path_to_auth:/auth \
    -e "REGISTRY_AUTH=htpasswd" \
    -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
    -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
    -v $host_path_to_certs:/certs \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
    $img

# Enables login ...
docker login $registry_domain:5000

# Run as a Service
docker secret create domain.crt $host_path_to_certs/domain.crt
docker secret create domain.key $host_path_to_certs/domain.key
docker service create \
    --name registry \
    --secret domain.crt \
    --secret domain.key \
    --constraint 'node.labels.registry==true' \
    #--mount type=bind,src=$host_path_to_images,dst=/var/lib/registry \
    -v $host_path_to_images:/var/lib/registry \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/run/secrets/domain.crt \
    -e REGISTRY_HTTP_TLS_KEY=/run/secrets/domain.key \
    -p 443:443 \
    --replicas 1 \
    $img
```
- Registry endpoint: `http://localhost:5000`
- Host paths (`$host_path*`) are to be created; exist only for their purpose here.
- LB/Reverse-proxy considerations 
  ([NGINX example](https://distribution.github.io/distribution/recipes/nginx/)):   
    - For all responses to any request under the “`/v2/`” url space, the `Docker-Distribution-API-Version` header should be set to the value “`registry/2.0`”, even for a `4xx` response. This header allows the docker engine to quickly resolve authentication realms and fallback to version 1 registries, if necessary. Confirming this is setup correctly can help avoid problems with fallback.  
    - In the same train of thought, you must make sure you are properly sending the `X-Forwarded-Proto`, `X-Forwarded-For`, and Host headers to their “`client-side`” values. Failure to do so usually makes the registry issue redirects to internal hostnames or downgrading from https to http.

### Use the local registry : Load/Push/Pull/Save

```bash
registry='localhost:5000'

# Load all saved images (*.tar) into Docker cache
find . -type f -exec docker load -i {} \;

# Tag/Push to local registry

list(){ docker image ls --format "table {{.Repository}}:{{.Tag}}"; }
export -f list

# (Re)Tag cached images (once), 
# replacing registry (if in name) with $registry, else prepending $registry/
list |grep -v TAG |grep -v $registry |xargs -IX /bin/bash -c '
    docker tag $1 $0/${1#*/}
' $registry X

# Push images (to $registry) 
list |grep $registry |xargs -IX /bin/bash -c '
    docker push $1
' _ X


# Get catalog of registry images
curl -s http://localhost:5000/v2/_catalog |jq .
#> {"repositories": ["abox",...,"kube-apiserver","kube-controller-manager",...]}

# Get all images (tags) of a repo
repo='abox'
curl -s http://$registry/v2/$repo/tags/list
#> {"name":"abox","tags":["1.0.1","1.0.0"]}

# Test : Pull from local registry
docker pull $registry/abox:1.0.1
# Verify
drt
#> localhost:5000/abox:1.0.1

# Save the registry image
tar="${img//\//.}"
docker save $img -o ${tar//:/_}.tar

```
- Must retag/push kuberenetes image: `coredns/coredns` to `coredns` else kubeadm config images pull fails for that one when pulling from our private registry.

### Setup for Remote (non localhost) Pull


```bash
# Add admin box hostname to Docker server's "insecure-registries" list 
sudo vim /etc/docker/daemon.json 
sudo systemctl restart docker
sudo systemctl status docker
# Push : Okay to push as "localhost:5000/NAME:TAG"
docker push localhost:5000/abox:latest
# Remove from local cache
docker image rm localhost:5000/abox:latest
# Pull from local registry at hostname
docker pull $(hostname):5000/abox:latest
```

@ `/etc/docker/daemon.json`

```json
{
    "proxies": {
        "http-proxy": "http://contractorproxyeast.northgrum.com:80",
        "https-proxy": "http://contractorproxyeast.northgrum.com:80",
        "no-proxy": "localhost,127.0.0.1,192.168.0.0/16,172.16.0.0/16,.entds.ngisn.com,.edn.entds.ngisn.com,.dilmgmt.c4isrt.com,.dil.es.northgrum.com,.ms.northgrum.com,.es.northgrum.com,.northgrum.com"
    },
    "insecure-registries": ["127.0.0.0/8","ONXWQBLCS121.entds.ngisn.com:5000"]
}

```

Pull from remote box

@ vm128

```
$ docker pull ONXWQBLCS121.entds.ngisn.com:5000/abox:latest
...
$ docker image ls
REPOSITORY                               TAG       IMAGE ID       CREATED       SIZE
ONXWQBLCS121.entds.ngisn.com:5000/abox   latest    9d742e017c49   4 weeks ago   225MB

```

Similarly, `containerd` must be reconfigured to pull from private, insecure (HTTP) registry. 
See `containerd/etc.containerd/*.toml` and `scripts/install-containerd-air-gap.sh`

```bash
# GET registry catalog JSON (and response header)
curl -i $(hostname):5000/v2/_catalog
```
```text
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
Docker-Distribution-Api-Version: registry/2.0
X-Content-Type-Options: nosniff
Date: Mon, 11 Mar 2024 16:41:07 GMT
Content-Length: 26

{"repositories":["abox"]}
```



### Login to remote registry

```bash
registry='ghcr.io'

docker login $registry -u $username -p $accesstoken
```

## Ansible

There are several conventions for configuring target machines.
A simple, secure method is to configure the script user (`gitops`) 
on the target(s) such that their password login is entirely disabled, 
making remote, key-based ssh login the only method of access,
and then creating a `/etc/sudoers.d/gitops` file that enables 
elevated privileges sans password entry.


- Install Ansible on admin node (not a cluster node)
- Prepare all target machines by running this script on each one. 
  It requires `root` privileges.
    - [`create_provisioner_target_node.sh`](create_provisioner_target_node.sh)



@ `~/.ansible/ansible.cfg`

```ini
[defaults]
action_warnings=False
inventory=inventory.cfg
deprecation_warnings=False
remote_user=gitops
[privilege_escalation]
become_user=root
[persistent_connection]
[connection]
[colors]
[selinux]
[diff]
[galaxy]
[inventory]
[netconf_connection]
ssh_config=${HOME}/.ssh/config
[paramiko_connection]
[jinja2]
[tags]

```

```bash
target='target'
# Create ansible.cfg
ansible-config init --disabled |tee ansible.cfg.disabled
# Ad-hoc : two commands
ansible $target -a hostname -a id
# Ad-hoc : Test is Ansible's ssh user (defaults to current user) has sudo sans password
ansible $target -a 'sudo ls -hl /etc/sudoers.d/'
# shell module
ansible $target -m ansible.builtin.shell -a hostname
# script module
ansible $target -m ansible.builtin.script -a foo.sh 
# playbook : script w/ args injected
ansible-playbook foo.yaml -e a=foo -e b=bar 

```

@ `foo.yaml`

```yaml
---
- name: Testing
  hosts: target
  vars:
    config_file_path: ~/.ansible/ansible.cfg
  become: true
  #become_flags: "-H -S -n"
  gather_facts: false
  tasks:
  - name: Task 1
    #command: "sh /home/entds.ngisn.com/4n52626/devops/ansible/foo.sh {{a}} {{b}}"
    #command: "sh $HOME/devops/ansible/foo.sh {{a}} {{b}}"
    command: "sh $HOME/devops/ansible/foo.sh"

```



## Loggigng 

- EFK stack with Helm 3 in Kubernetes : https://kamrul.dev/deploy-efk-stack-with-helm-3-in-kubernetes/ 
- EFK Helm : https://www.devopsschool.com/blog/how-to-deploy-elasticsearch-fluentd-and-kibana-efk-in-kubernetes/ 
    - Elasticsearch : https://artifacthub.io/packages/helm/elastic/elasticsearch
    - Fluentd : https://artifacthub.io/packages/helm/bitnami/fluentd
    - Kibana :  https://artifacthub.io/packages/helm/elastic/kibana
- EFK Logging Operator : https://operatorhub.io/operator/logging-operator

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add elastic https://helm.elastic.co
helm repo update
helm install elasticsearch elastic/elasticsearch --version <version> -f your_custom_values.yaml
helm install fluentd bitnami/fluentd --version <version> -f your_custom_values_fluentd.yaml
helm install kibana elastic/kibana --version <version> -f your_custom_values_kibana.yaml
```

## Observability

- Prometheus 
- Grafana : https://artifacthub.io/packages/helm/grafana/grafana 
- EFK stack 
- Jaeger

After installation, you might need to perform additional configuration to integrate these components, such as configuring Grafana to use Prometheus as a data source or setting up Fluentd to collect logs and forward them to Elasticsearch. 

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add elastic https://helm.elastic.co
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update
helm install my-prometheus prometheus-community/prometheus
helm install my-grafana grafana/grafana
helm install my-elasticsearch elastic/elasticsearch
helm install my-fluentd bitnami/fluentd
helm install my-kibana elastic/kibana
helm install my-jaeger jaegertracing/jaeger
```

## Big Data in Motion

- Kafka : https://developer.confluent.io/
- Kafka Quick Start : https://kafka.apache.org/quickstart
- Kraft (vs Zookeeper) : https://developer.confluent.io/learn/kraft/
- Kafka on K8s : https://www.redhat.com/en/topics/integration/why-run-apache-kafka-on-kubernetes
- Kafka on K8s : https://strimzi.io/
- ksqlDB : https://ksqldb.io/
- Secure : https://www.confluent.io/blog/secure-kafka-deployment-best-practices/

## Big Data at Rest

- Hadoop / HDFS

## GitOps

- Argo CD : https://github.com/argoproj-labs

