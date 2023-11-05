#!/usr/bin/env bash
# CKA Method is dated:
# kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
# WIP : https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements

exit # WIP

export calico_manifests='https://raw.githubusercontent.com/projectcalico/calico/v3.26.3/manifests'
# 1. Install the Tigera Calico operator and custom resource definitions.
kubectl create -f $calico_manifests/tigera-operator.yaml

# 2. Install Calico by creating the necessary custom resource. 
## https://docs.tigera.io/calico/latest/reference/installation/api
kubectl create -f $calico_manifests/custom-resources.yaml

# 3. Monitor
watch kubectl get pods -n calico-system

# Remove taints on control plane so can schedule workloads on node.
# kubectl taint nodes --all node-role.kubernetes.io/control-plane-
# kubectl taint nodes --all node-role.kubernetes.io/master-