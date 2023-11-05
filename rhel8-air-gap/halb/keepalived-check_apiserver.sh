#!/usr/bin/env bash
##################################################
# keepalived : vrrp_script
# @ /etc/keepalived/check_apiserver.sh
# Executed unless VIP is set externally (static).
# See : man keepalived.conf
##################################################
set -a
vip=10.160.113.234
vip_port=8443
upstream_port=6443

errorExit(){ 
    echo "* * * $*" 1>&2
    exit 1
}
testHealth(){
    curl --silent --max-time 3 --insecure -o /dev/null $1
}
set +a

# Test the upstream
url="https://localhost:${upstream_port}/"
testHealth $url || errorExit "Error GET $url"

# Test the VIP only if this host has it.
[[ $(ip addr |grep $vip) ]] && {
    url="https://${vip}:${vip_port}/"
    testHealth $url || errorExit "Error GET $url"
}

exit 0 
