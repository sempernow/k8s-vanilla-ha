#!/usr/bin/env bash
###########################
# Load OCI images
###########################

dir=${1:-$(pwd)}/oci-images
pushd "$dir"
echo "@ $(pwd)"

# Load
find . -type f -iname '*.tar.gz' -exec docker load -i {} \;

popd
exit 0
######
