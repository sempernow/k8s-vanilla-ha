#!/usr/bin/env bash
##########################################################
# OCI images : Tag and push to declared (local) registry
##########################################################

#registry='localhost:5000'
registry=${1:-localhost:5000}

echo "=== Tag and push to $registry"

list(){ docker image ls --format "table {{.Repository}}:{{.Tag}}"; }
export -f list

# (Re)Tag cached images (once), 
# replacing registry (if in name) with $registry, else prepending $registry/
list |grep -v TAG |grep -v $registry |xargs -I{} /bin/bash -c '
    docker tag $1 $0/${1#*/}
' $registry {}

# Push images (to $registry) 
list |grep $registry |xargs -I{} /bin/bash -c '
    docker push $1
' _ {}


exit 0
######

# Registry @ vm121 and client (curl) @ vm090
curl -s --noproxy '*' http://10.160.113.248:5000/v2/_catalog |jq .

