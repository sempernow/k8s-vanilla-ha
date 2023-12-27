## @ https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
## @ https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-InitConfiguration
## Certificate Key:
## See "kubeadm init" output : ... --certificate-key <KEY>
## K8S_CERTIFICATE_KEY=$(sudo kubeadm certs certificate-key)
certificateKey: K8S_CERTIFICATE_KEY 
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  ## token=$(kubeadm token generate)
  token: K8S_BOOTSTRAP_TOKEN
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
# localAPIEndpoint is NOT the HA-LB endpoint
# localAPIEndpoint:
#   advertiseAddress: 1.2.3.4  # Host IP address
#   bindPort: 6443             # Default: 6443
nodeRegistration:
  ignorePreflightErrors:
  - Mem
  #imagePullPolicy: IfNotPresent
  #criSocket: unix:///var/run/containerd/containerd.sock
  criSocket: K8S_CRI_SOCKET
  #name: node
  #taints: null  # Default taints on control nodes
  #taints: []    # No taints on control nodes
  kubeletExtraArgs: # See kubelet --help
    v: "5" 
    pod-cidr: K8S_POD_CIDR 
    cgroup-driver: K8S_CGROUP_DRIVER 
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
## @ https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-ClusterConfiguration
kubernetesVersion: K8S_VERSION
imageRepository: K8S_REGISTRY
apiServer:
  timeoutForControlPlane: 4m0s
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
## HA LB Endpoint
controlPlaneEndpoint: K8S_CONTROL_PLANE_IP:K8S_CONTROL_PLANE_PORT
networking:
  serviceSubnet: K8S_SERVICE_CIDR 
  podSubnet: K8S_POD_CIDR 
  dnsDomain: cluster.local
scheduler: {}
# ---
# apiVersion: kubelet.config.k8s.io/v1beta1
# kind: KubeletConfiguration
# ## PER NODE
# ## @ https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration
# ## ConfigMaps, kubelet-config-1, exist PER NODE.
# ## kubectl get configmap kubelet-config-1 -n kube-system -o json |jq -Mr .data.kubelet |base64 -d 
# ## Restart kubelet.service on any change to its --config CONFIG
# enableServer: true 
# #cgroupDriver: systemd # systemd || cgroupfs
# imageGCHighThresholdPercent: 85
# imageGCLowThresholdPercent: 80 
# ## TLS Params : See https://pkg.go.dev/crypto/tls#pkg-constants
# #tlsCipherSuites: []
# # tlsMinVersion: VersionTLS12 #... VersionTLS12 || VersionTLS13 
# ---
# apiVersion: kubeproxy.config.k8s.io/v1alpha1
# kind: KubeProxyConfiguration
# ## @ https://kubernetes.io/docs/reference/config-api/kube-proxy-config.v1alpha1/#kubeproxy-config-k8s-io-v1alpha1-KubeProxyConfiguration
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
## @ https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-JoinConfiguration
discovery:
  bootstrapToken:
    ## Generate token and CA certificate : kubeadm token create
    ## CA certificate @ /etc/kubernetes/pki/ca.crt
    token: K8S_BOOTSTRAP_TOKEN
    apiServerEndpoint: kube-apiserver:6443
    ## CA-Certificate Hash(es):
    ## See "kubeadm init" output: 
    ## --discovery-token-ca-cert-hash sha256:<hex-encoded-value>
    ## Is hash of "Subject Public Key Info" (SPKI) object
    ## Is DISABLED (Unsafe) if empty.
    ## Create a caCertHash
    ## (The SHA-256 hash of the public key extracted from ca.crt)
    ## K8S_CA_CERT_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt |openssl rsa -pubin -outform der 2>/dev/null |openssl dgst -sha256 -hex |sed 's/^.* //')
    #caCertHashes: []
    caCertHashes: 
    - K8S_CA_CERT_HASH
    # Default: true
    unsafeSkipCAVerification: false 
  timeout: 5m0s
  tlsBootstrapToken: K8S_BOOTSTRAP_TOKEN 
controlPlane:
  localAPIEndpoint:
    advertiseAddress: K8S_CONTROL_PLANE_IP
    bindPort: K8S_CONTROL_PLANE_PORT
# This node only:
nodeRegistration: 
  ignorePreflightErrors:
  - Mem
  imagePullPolicy: IfNotPresent
  criSocket: K8S_CRI_SOCKET 
  #name: node
  #taints: null # Default taints
  #taints: []   # No taints
  # See kubelet --help
  kubeletExtraArgs: 
    v: K8S_VERBOSITY            
    pod-cidr: K8S_POD_CIDR
    cgroup-driver: K8S_CGROUP_DRIVER
