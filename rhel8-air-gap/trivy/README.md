# [Trivy : CVEs Scanner](https://confluence.edn.entds.ngisn.com/display/ONX/Trivy+CVE+Scanner)

Trivy scans OCI images, OS folders, and Kubernetes clusters.

@ `https://aquasecurity.github.io/trivy/v0.49/`

## Install

```bash
mkdir -p trivy
cd trivy 

# Download/Extract the binary
ver='0.49.1'
tarball="trivy_${ver}_Linux-64bit.tar.gz"
url=https://github.com/aquasecurity/trivy/releases/download/v${ver}/$tarball
curl -LO $url && tar -xvaf $tarball

# Install it
sudo cp trivy /usr/local/bin/
```

## Use

```bash
# Update its CVE database
trivy image --download-db-only 

# Scan an image and log results
trivy image ubuntu:latest 

# Scan k8s cluster
trivy k8s --report summary cluster

# Scan FS
trivy fs --scanners vuln,secret,misconfig $project_dir/

```


### [Trivy Operator @ Kubernetes](https://aquasecurity.github.io/trivy-operator/latest/)

Install by Helm 

```bash
ver='0.20.5' # Chart; trivy v0.18.4
helm repo add trivy-operator https://aquasecurity.github.io/helm-charts/
helm install trivy trivy-operator/trivy-operator --version $ver
```
- Images : ghcr.io/
    - aquasecurity/trivy
    - aquasecurity/trivy-operator
    - aquasecurity/node-collector
    - aquasecurity/trivy-db
    - aquasecurity/trivy-java-db
