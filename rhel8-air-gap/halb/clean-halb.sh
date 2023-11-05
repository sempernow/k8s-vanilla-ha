#!/usr/bin/env bash
####################################################
# Configure the HA LB : Clean for install
####################################################
#>>>  DEPRICATED : Added to configure-halb.sh
####################################################
sudo systemctl disable --now keepalived
sudo systemctl disable --now haproxy

sleep 2

# If device has VIP, then remove VIP 
# (keepalived shutdown should have done so already.)
[[ $(ip -brief -4 addr show dev ${2} |grep ${1}) ]] && {
    sudo ip addr del ${1}/32 dev ${2}
    echo '=== VIP REMOVED'
    sleep 2
}
ip -brief -4 addr show dev ${2}

[[ $(ip -brief -4 addr show dev ${2} |grep ${1}) ]] && {
    echo 'FAIL : VIP remains'
    exit 1
}

exit 0