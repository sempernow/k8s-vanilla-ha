# [CNCF Distribution Registry](https://distribution.github.io/distribution/) 

>The Registry is a stateless, highly scalable server-side application that stores and lets you distribute container images and other content. The Registry is open-source, under the permissive Apache license.

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

## Define helper function to list only REPO:TAG of all cached images
list(){ docker image ls --format "table {{.Repository}}:{{.Tag}}"; }
export -f list

## (Re)Tag cached images (once), 
## replacing registry (if in name) with $registry, else prepending $registry/
list |grep -v TAG |grep -v $registry |xargs -IX /bin/bash -c '
    docker tag $1 $0/${1#*/}
' $registry X

## Push images (to $registry) 
list |grep $registry |xargs -IX /bin/bash -c '
    docker push $1
' _ X


# Get catalog of registry images
curl -s http://localhost:5000/v2/_catalog |jq .
#> {"repositories": ["abox",...,"kube-apiserver","kube-controller-manager",...]}

# Registry @ vm121 and client (curl) @ vm090
curl -s --noproxy '*' http://10.160.113.248:5000/v2/_catalog |jq .


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

### Login to remote registry

```bash
registry='ghcr.io'

docker login $registry -u $username -p $accesstoken
```

