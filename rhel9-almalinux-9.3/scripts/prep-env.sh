#!/usr/bin/env bash

echo '=== /etc/hosts : NO CHANGE'
cat /etc/hosts

[[ $(getenforce |grep Permissive) ]] && {
echo '=== SELinux : NO CHANGE'
    getenforce
    
    exit 0 
}

# SELinux mod : now and forever
echo '=== SELinux : Set to Permissive'
echo '@ SELinux : BEFORE mod'
getenforce
echo '@ SELinux : Reset/Configure:'
sudo setenforce 0 # set to Permissive (Unreliable)
# "permissive" is "disabled", but logs what would have been if "enforcing".
#sudo sed -i -e 's/^SELINUX=permissive/SELINUX=disabled/' /etc/selinux/config
#sudo sed -i -e 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
sudo sed -i -e 's/^SELINUX=disabled/SELINUX=permissive/' /etc/selinux/config
sudo sed -i -e 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
echo '@ SELinux : AFTER mod'
sestatus |grep 'SELinux status'
getenforce

exit 0

#########
# TODO 
#########

## Configure local DNS (once) : self recognition only
[[ $(cat /etc/hosts |grep $(hostname)) ]] && { 
    echo '=== /etc/hosts : ALREADY CONFIGURED'
    cat /etc/hosts
    
    exit 0
} 

echo '=== Reset /etc/hosts'

vm_ip(){
    # Print IPv4 address of an host ($1). 
    [[ $1 ]] || exit 99
    #echo $(cat ~/.ssh/config |grep -A4 -B2 $1 |grep Hostname |head -n 1 |awk '{printf $2}')
    echo $(nslookup $1 |grep -A1 $1 |grep Address |awk '{printf $2}')
}

[[ $HALB_VIP ]] || { echo "=== ENVIRONMENT is NOT CONFIGURED";exit 99; }

pushd ${BASH_SOURCE%/*}

# VIP must be static and not assignable by the subnet's DHCP server.
vip="$HALB_VIP"
# Set FQDN
# Get/Set IP address of each LB node from ~/.ssh/config
# echo "${HALB_FQDN_1%%.*}"
# vm_ip ${HALB_FQDN_1%%.*}
# exit

# Expects hostnames args
lb_1_ipv4=$(vm_ip ${1%%.*})
lb_2_ipv4=$(vm_ip ${2%%.*})
lb_3_ipv4=$(vm_ip ${3%%.*})
# Smoke test these gotten node-IP values : Abort on fail
[[ $lb_1_ipv4 ]] || { echo '=== FAIL @ lb_1_ipv4';exit 21; }
[[ $lb_2_ipv4 ]] || { echo '=== FAIL @ lb_2_ipv4';exit 22; }
[[ $lb_3_ipv4 ]] || { echo '=== FAIL @ lb_3_ipv4';exit 23; }


# PRESERVE any EXISTING entries
cat <<-EOH |sudo tee -a /etc/hosts
127.0.0.1 $(hostname)
::1       $(hostname)
EOH
