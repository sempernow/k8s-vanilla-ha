#!/usr/bin/env bash
# https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements
# CKA Method is manifest method; not advised by Calico:
# kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
# Calico advises Operator method:
# https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises
# 
exit # WIP

# Manifest Method 
# https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises
wget -nv https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/calico.yaml
kubectl apply -f calico.yaml

exit

# Operator Method
export calico_manifests='https://raw.githubusercontent.com/projectcalico/calico/v3.26.3/manifests'
## 1. Install the Tigera Calico operator
kubectl create -f $calico_manifests/tigera-operator.yaml

## 2. Download CRDs
wget -nv $calico_manifests/custom-resources.yaml
## Modify calico.yaml
### https://docs.tigera.io/calico/latest/reference/installation/api
## Install CRDs
kubectl create -f custom-resources.yaml

# 3. Monitor
watch kubectl get pods -n calico-system

# Next Steps
## https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises#next-steps

# Remove taints on control plane so can schedule workloads on node.
# kubectl taint nodes --all node-role.kubernetes.io/control-plane-
# kubectl taint nodes --all node-role.kubernetes.io/master-