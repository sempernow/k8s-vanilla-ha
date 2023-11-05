#!/usr/bin/env bash 
# Reset no_proxy param of /etc/environment

vm_ip(){
    # Print IPv4 address of an ssh-configured Host ($1). 
    [[ $1 ]] || exit 99
    echo $(cat ~/.ssh/config |grep -A4 -B2 $1 |grep Hostname |head -n 1 |awk '{printf $2}')
}


lb_1_ipv4=$(vm_ip ${HALB_FQDN_1%%.*})
lb_2_ipv4=$(vm_ip ${HALB_FQDN_2%%.*})
lb_3_ipv4=$(vm_ip ${HALB_FQDN_3%%.*})
# Smoke test these gotten node-IP values : Abort on fail
[[ $lb_1_ipv4 ]] || { echo '=== FAIL @ lb_1_ipv4';exit 21; }
[[ $lb_2_ipv4 ]] || { echo '=== FAIL @ lb_2_ipv4';exit 22; }
[[ $lb_3_ipv4 ]] || { echo '=== FAIL @ lb_3_ipv4';exit 23; }

no_proxy="$(cat /etc/environment |grep -i no_proxy |cut -d'=' -f2)"

halb_addr_list="
    $HALB_CIDR
    .$HALB_FQDN_1 
    .$HALB_FQDN_2 
    .$HALB_FQDN_3
"


for addr in $halb_addr_list; do no_proxy=$no_proxy,$addr;done

echo "$no_proxy"
exit

[[ $1 ]] || {
    echo "
        This script appends address list to no_proxy param of /etc/environment

        USAGE: ${BASH_SOURCE##*/} foo.com 10.160.113.100 ...
        
        REQUIREs one or more HALB addresses.
    "
    exit 1

}

pushd ${BASH_SOURCE%/*}

no_proxy="$(cat /etc/environment |grep -i no_proxy |cut -d'=' -f2)"

for addr in $@; do no_proxy=$no_proxy,$addr;done


sed  "/no_proxy/d" /etc/environment >etc.environment
echo "$no_proxy" |tee -a etc.environment

popd
