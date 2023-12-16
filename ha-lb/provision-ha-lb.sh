#!/usr/bin/env bash
#################################################
# Highly Available (HA) Load Balancer (LB)
#
# This script configures a 2-node HA-LB
# built of HAProxy and Keepalived. 
#################################################
# >>>  Modify these settings per environment  <<<
#################################################

vm_ip(){
    # Print the IPv4 address of an ssh-configured Host ($1). See ~/.ssh/config.
    [[ $1 ]] || exit 99
    echo $(cat ~/.ssh/config |grep -A4 -B2 $1 |grep Hostname |head -n 1 |cut -d' ' -f2)
}

set -a  # EXPORT ALL

# Environment
echo '=== Environment'
lb_config_files="keepalived.conf check_apiserver.sh haproxy.cfg"
## Reset these LB-node values per Hypervisor/VM environment 
ssh_configured_hosts='a0 a1'
lb_1_fqdn='a0.local'
lb_2_fqdn='a1.local'
device='eth0' # Applicable network interface device common to all LB nodes
## VIP must be static and not assignable by the DHCP server.
vip='192.168.0.100' 
vip6='::ffff:c0a8:64'
## Get IP address of each LB node from ~/.ssh/config
lb_1_ipv4=$(vm_ip ${lb_1_fqdn%%.*})
lb_2_ipv4=$(vm_ip ${lb_2_fqdn%%.*})
## Smoke test these gotten node-IP values : Abort on fail
[[ $(echo ${lb_1_ipv4} |cut -d'.' -f4) ]] \
    || { echo '=== FAIL @ lb_1_ipv4';exit 22; }
[[ $(echo ${lb_2_ipv4} |cut -d'.' -f4) ]] \
    || { echo '=== FAIL @ lb_2_ipv4';exit 22; }

_ssh() { 
    mode=$1;shift
    for vm in $ssh_configured_hosts
    do
        echo "=== @ $vm : $1 $2 $3 ..."
        [[ $mode == '-s' ]] && ssh $vm "/bin/bash -s" < "$@"
        [[ $mode == '-c' ]] && ssh $vm "/bin/bash -c" "$@"
        [[ $mode == '-x' ]] && ssh $vm "$@"
        [[ $mode == '-u' ]] && scp -p "$1" "$vm:$1"
        [[ $mode == '-d' ]] && scp -p "$vm:$1" "$vm_$1"
    done 
}

set +a  # END EXPORT ALL 


echo "=== @ $(hostname) : Local host DNS : Append HA-LB node entries to /etc/hosts"
# @ local host, add each LB node entry (once) to /etc/hosts file
[[ $(grep $lb_1_fqdn /etc/hosts) ]] \
    || echo $lb_1_ipv4 $lb_1_fqdn >> /etc/hosts
[[ $(grep $lb_2_fqdn /etc/hosts) ]] \
    || echo $lb_2_ipv4 $lb_2_fqdn >> /etc/hosts
cat /etc/hosts

echo '=== @ VMs : Local host DNS : Reset /etc/hosts of each HA-LB node'
_ssh -x "
    [[ \$(grep 'localhost $lb_1_fqdn' /etc/hosts) ]] && sudo sed -i 's,localhost $lb_1_fqdn,localhost,' /etc/hosts
    [[ \$(grep 'localhost $lb_2_fqdn' /etc/hosts) ]] && sudo sed -i 's,localhost $lb_2_fqdn,localhost,' /etc/hosts
    [[ \$(grep '$lb_1_ipv4 $lb_1_fqdn' /etc/hosts) ]] || { echo '$lb_1_ipv4 $lb_1_fqdn' |sudo tee -a /etc/hosts; }
    [[ \$(grep '$lb_2_ipv4 $lb_2_fqdn' /etc/hosts) ]] || { echo '$lb_2_ipv4 $lb_2_fqdn' |sudo tee -a /etc/hosts; }
    echo '@ cat /etc/hosts'
    cat /etc/hosts
"

echo '=== Install packages'
_ssh -x sudo yum -y install keepalived haproxy psmisc 

echo '=== Upload HA-LB cfg/conf template files'
printf "%s\n" $lb_config_files |xargs -IX /bin/bash -c '_ssh -u $1 .' _ X

echo '=== Keepalived conf'
## Generate a password common to all the LB nodes
pass="$(cat /proc/sys/kernel/random/uuid)" 
##...Static UUIDv5 namespaced (rotated) per day or so would be better.
## "priority VAL" of each SLAVE must be unique and lower than that of MASTER.
_ssh -x "
    chmod +x check_apiserver.sh
    sudo cp -p check_apiserver.sh /etc/keepalived/
    sudo sed -i 's/SET_VIP/$vip/' /etc/keepalived/check_apiserver.sh
    sudo cp -p keepalived.conf /etc/keepalived/
    sudo sed -i 's/SET_DEVICE/$device/' /etc/keepalived/keepalived.conf
    sudo sed -i 's/SET_PASS/$pass/' /etc/keepalived/keepalived.conf
    sudo sed -i 's/SET_VIP/$vip/' /etc/keepalived/keepalived.conf
    [[ \$(hostname) == $lb_2_fqdn ]] && {
        sudo sed -i 's/state MASTER/state SLAVE/'  /etc/keepalived/keepalived.conf
        sudo sed -i 's/priority 255/priority 254/' /etc/keepalived/keepalived.conf
    }
"

echo '=== HAProxy cfg'
## Replace pattern "LB_?_FQDN LB_?_IPV4" with declared values.
_ssh -x "
    sudo cp -p haproxy.cfg /etc/haproxy/
    sudo sed -i 's/LB_1_FQDN[[:space:]]LB_1_IPV4/$lb_1_fqdn $lb_1_ipv4/' /etc/haproxy/haproxy.cfg
    sudo sed -i 's/LB_2_FQDN[[:space:]]LB_2_IPV4/$lb_2_fqdn $lb_2_ipv4/' /etc/haproxy/haproxy.cfg
"

# Start and enable services
_ssh -x '
    sudo systemctl --now enable keepalived
    sudo systemctl --now enable haproxy
'

# Firewalld
echo '=== Firewalld mods'
## Allow VRRP Control Port
_ssh -x '
    sudo firewall-cmd --permanent --add-port=112/udp 
'
## Allow HAProxy listen to HTTP(S) traffic 
_ssh -x '
    sudo firewall-cmd --permanent --add-port=80/tcp
    sudo firewall-cmd --permanent --add-port=443/tcp
    sudo firewall-cmd --permanent --add-port=6443/tcp
    sudo firewall-cmd --permanent --add-port=8443/tcp
'
## Allow traffic to/from VIP address
_ssh -x "
    sudo firewall-cmd --permanent --add-rich-rule='rule family=\"ipv4\" source address=\"$vip\" accept'
    sudo firewall-cmd --permanent --add-rich-rule='rule family=\"ipv6\" source address=\"$vip6\" accept'
"
## Reload 
_ssh -x sudo firewall-cmd --reload

# Verify VIP
echo '=== VIP : Verify HA-LB dynamics'
## Show 'global secondary' route
_ssh -x ip -4 addr |grep $vip
## Verify connectivity
[[ $(type -t nc) ]] && nc -zv $vip 8443 || echo 'Use `nc -zv $vip 8443` to test connectivity'
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
} || echo 'Use `ping -4 $vip` to verify HA dynamics (power/toggle VMs).'