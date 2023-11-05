#!/usr/bin/env bash
#################################################
# Highly Available (HA) Load Balancer (LB)
#
# This script configures a 2-node HA-LB
# built of HAProxy and Keepalived. 
#################################################
# >>>  Modify these settings per environment  <<<
#################################################
[[ $(type -t ansibash) ]] || { echo '=== REQUIREs : ansibash';exit 0; }

# This script requires its PWD to be its own directory.
cd "${BASH_SOURCE%/*}"

set -a  # Export all

vm_ip(){
    # Print the IPv4 address of an ssh-configured Host ($1). See ~/.ssh/config.
    [[ $1 ]] || exit 99
    echo $(cat ~/.ssh/config |grep -A4 -B2 $1 |grep Hostname |head -n 1 |cut -d' ' -f2)
}

# Environment
echo '=== Environment'
lb_config_files="keepalived.conf.tpl keepalived-check_apiserver.sh.tpl haproxy.cfg.tpl haproxy-99-haproxy.conf"
## VIP must be static and not assignable by the DHCP server.
vip="${HALB_VIP:-192.168.0.100}"
vip6="${HALB_VIP6:-::ffff:c0a8:64}"
vport="${HALB_PORT:-8443}"
device="${HALB_DEVICE:-eth0}" # Network interface common to all LB nodes
## Set FQDN
fqdn_1=$HALB_FQDN_1
fqdn_2=$HALB_FQDN_2
## Get/Set IP address of each LB node from ~/.ssh/config
ipv4_1=$(vm_ip ${fqdn_1%%.*})
ipv4_2=$(vm_ip ${fqdn_2%%.*})
## Smoke test these gotten node-IP values : Abort on fail
[[ $ipv4_1 ]] || { echo '=== FAIL @ ipv4_1';exit 22; }
[[ $ipv4_2 ]] || { echo '=== FAIL @ ipv4_2';exit 23; }
## Set the target VMs : hosts of the HALB
ssh_configured_hosts="$fqdn_1 $fqdn_2"

# Agent
_ssh() { 
    # mode=$1;shift
    # for vm in $ssh_configured_hosts
    # do
    #     echo "=== @ $vm : $1 $2 $3 ..."
    #     [[ $mode == '-s' ]] && ssh $vm "/bin/bash -s" < "$@"
    #     [[ $mode == '-c' ]] && ssh $vm "/bin/bash -c" "$@"
    #     [[ $mode == '-x' ]] && ssh $vm "$@"
    #     [[ $mode == '-u' ]] && scp -p "$1" "$vm:$1"
    #     [[ $mode == '-d' ]] && scp -p "$vm:$1" "$vm_$1"
    # done 
    ANSIBASH_TARGET_LIST="$ssh_configured_hosts"
    ansibash "$@"
}

set +a  # END Export all 

# echo "=== @ $(hostname) : Local host DNS : Append HA-LB node entries to /etc/hosts"
# # @ local host, add each LB node entry (once) to /etc/hosts file
# [[ $(grep $fqdn_1 /etc/hosts) ]] \
#     || echo $ipv4_1 $fqdn_1 >> /etc/hosts
# [[ $(grep $fqdn_2 /etc/hosts) ]] \
#     || echo $ipv4_2 $fqdn_2 >> /etc/hosts
# cat /etc/hosts

echo '=== @ VMs : localhost DNS : Reset /etc/hosts of each HA-LB node'
_ssh -x "
    [[ \$(grep 'localhost $fqdn_1' /etc/hosts) ]] && sudo sed -i 's,localhost $fqdn_1,localhost,' /etc/hosts
    [[ \$(grep 'localhost $fqdn_2' /etc/hosts) ]] && sudo sed -i 's,localhost $fqdn_2,localhost,' /etc/hosts
    [[ \$(grep '$ipv4_1 $fqdn_1' /etc/hosts) ]] || { echo '$ipv4_1 $fqdn_1' |sudo tee -a /etc/hosts; }
    [[ \$(grep '$ipv4_2 $fqdn_2' /etc/hosts) ]] || { echo '$ipv4_2 $fqdn_2' |sudo tee -a /etc/hosts; }
    echo '@ cat /etc/hosts'
    cat /etc/hosts
"

echo '=== Install packages'
_ssh -x sudo yum -y install keepalived haproxy psmisc 

echo '=== Upload HA-LB configuration template files'
printf "%s\n" $lb_config_files |xargs -IX /bin/bash -c '_ssh -u $1 .' _ X

echo '=== Keepalived conf'
## Generate a password common to all the LB nodes
pass="$(cat /proc/sys/kernel/random/uuid)" 
##...Static UUIDv5 namespaced (rotated) per day or so would be better.
## "priority VAL" of each SLAVE must be unique and lower than that of MASTER.
target=/etc/keepalived/check_apiserver.sh
_ssh -x "
    sudo cp keepalived-check_apiserver.sh.tpl $target
    sudo chmod +x $target
    sudo sed -i 's/SET_VIP/$vip/' $target
"
target=/etc/keepalived/keepalived.conf
_ssh -x "
    sudo cp keepalived.conf.tpl $target
    sudo sed -i 's/SET_DEVICE/$device/' $target
    sudo sed -i 's/SET_PASS/$pass/' $target
    sudo sed -i 's/SET_VIP/$vip/' $target
    [[ \$(hostname) == $fqdn_2 ]] && {
        sudo sed -i 's/state MASTER/state SLAVE/'  $target
        sudo sed -i 's/priority 255/priority 254/' $target
    }
"

echo '=== HAProxy cfg'
## Replace pattern "LB_?_FQDN LB_?_IPV4" with declared values.
target=/etc/haproxy/haproxy.cfg
_ssh -x "
    sudo mkdir -p /var/lib/haproxy/dev
    sudo cp 99-haproxy.conf /etc/rsyslog.d/
    sudo cp haproxy.cfg.tpl $target
    sudo sed -i 's/LB_1_FQDN[[:space:]]LB_1_IPV4/$fqdn_1 $ipv4_1/' $target
    sudo sed -i 's/LB_2_FQDN[[:space:]]LB_2_IPV4/$fqdn_2 $ipv4_2/' $target
    sudo sed -i 's/LB_PORT/$vport/' $target
    sudo setsebool -P haproxy_connect_any 1
"

# Start and enable services
_ssh -x '
    sudo systemctl daemon-reload
    sudo systemctl restart rsyslog.service
    sudo systemctl --now enable keepalived
    sudo systemctl --now enable haproxy
'

# Firewalld
# echo '=== Firewalld mods'
# ## Allow VRRP Control Port (112/tcp)
# _ssh -x '
#     sudo firewall-cmd --permanent --add-port=112/udp 
# '
# ## Allow HAProxy listen to HTTP(S) traffic 
# _ssh -x '
#     sudo firewall-cmd --permanent --add-port=80/tcp
#     sudo firewall-cmd --permanent --add-port=443/tcp
#     sudo firewall-cmd --permanent --add-port=6443/tcp
#     sudo firewall-cmd --permanent --add-port=8443/tcp
# '
# _ssh -x "
    
#     ## Allow traffic to/from VIP address
#     sudo firewall-cmd --permanent --add-rich-rule='rule family=\"ipv4\" source address=\"$vip\" accept'
#     sudo firewall-cmd --permanent --add-rich-rule='rule family=\"ipv6\" source address=\"$vip6\" accept'
# "
# ## Reload 
# _ssh -x sudo firewall-cmd --reload
_ssh -s firewalld-halb.sh

# Verify VIP
echo '=== VIP : Verify HA-LB dynamics'
## Show 'global secondary' route
_ssh -x ip -4 addr |grep $vip
## Verify connectivity
[[ $(type -t nc) ]] && nc -zv $vip $vport \
    || echo "Use \`nc -zv $vip $vport\` to test connectivity"
## Verify HA dynamics
[[ $(type -t ping) ]] && {
    echo '
        While ping is running, use the hypervisor 
        to power off one or more HA-LB nodes.
        Connectivity should not be interrupted 
        as long as at least one such node is running.

        Press Enter when ready to test. 

        Ctrl+C to kill.
    '
    read
    ping -4 $vip 
} || echo "Use \`ping -4 $vip\` to verify HA dynamics (power/toggle VMs)."