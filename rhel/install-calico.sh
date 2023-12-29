#!/usr/bin/env bash
# https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements
# CKA Method is manifest method; not advised by Calico:
# Calico advises Operator method:
# https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises
# 

ver='3.27.0'
export base=https://raw.githubusercontent.com/projectcalico/calico/v${ver}/manifests

manifest_method() {
    # Manifest Method 
    # https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises
    wget -nv -O calico.yaml $base/calico.yaml
    kubectl apply -f calico.yaml
}

operator_method(){
    # Operator Method
    
    ## 1. Install the Tigera Calico operator
    wget -nv $base/tigera-operator.yaml
    kubectl create -f tigera-operator.yaml
    ## 2. Download CRDs
    wget -nv $base/custom-resources.yaml
    ## Modify calico.yaml
    vim custom-resources.yaml
    ### https://docs.tigera.io/calico/latest/reference/installation/api
    ## Install CRDs
    kubectl create -f custom-resources.yaml
    ## 3. Verify/Monitor
    #watch kubectl get pods -n calico-system
    ## 4. UPDATE : calicoctl NOT NECESSARY; use Calico API server instead
    ## 4. Install calicoctl binary on signle node
    ### https://docs.tigera.io/calico/latest/operations/calicoctl/install
    # wget -nv -O calicoctl https://github.com/projectcalico/calico/releases/download/v${ver}/calicoctl-linux-amd64
    # sudo mv calicoctl /usr/local/bin/calicoctl
    # sudo chmod +x /usr/local/bin/calicoctl
    ## 4. Install Calico API server
    wget -nv -O calico-apiserver.yaml $base/apiserver.yaml
    kubectl create -f calico-apiserver.yaml

    ## 6. Configure BGP
    ### https://docs.tigera.io/calico/latest/networking/configuring/bgp

    ## Next Steps
    ### https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises#next-steps

    # Remove taints on control plane so can schedule workloads on node.
    # kubectl taint nodes --all node-role.kubernetes.io/control-plane-
    # kubectl taint nodes --all node-role.kubernetes.io/master-
}

manifest_method
