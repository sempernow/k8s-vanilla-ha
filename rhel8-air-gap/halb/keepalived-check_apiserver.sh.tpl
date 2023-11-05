#!/usr/bin/env bash
##################################################
# keepalived : vrrp_script
# @ /etc/keepalived/SET_SCRIPT_FNAME
# Executed unless VIP is set externally (static).
# See : man keepalived.conf
##################################################
set -a
vip=SET_VIP
vip_port=SET_PORT_VIP
upstream_port=SET_PORT_UPSTREAM

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
