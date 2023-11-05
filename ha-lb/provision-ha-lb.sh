#!/bin/bash
set -a  # EXPORT ALL ...

# Environment
required_files="keepalived.conf check_apiserver.sh haproxy.cfg"
ssh_configured_hosts='a0 a1'
vip='192.168.0.100'
vip6='0:0:0:0:0:ffff:c0a8:0064'
lb_1_fqdn='a0.local'
lb_1_ipv4='192.168.0.83'
lb_2_fqdn='a1.local'
lb_2_ipv4='192.168.0.87'

# Add entries of all LB nodes at local /etc/hosts file
[[ $(grep $lb_1_fqdn /etc/hosts) ]] || echo $lb_1_ipv4 $lb_1_fqdn >> /etc/hosts
[[ $(grep $lb_2_fqdn /etc/hosts) ]] || echo $lb_2_ipv4 $lb_2_fqdn >> /etc/hosts

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

set +a  # END EXPORT ALL ...

# Set local DNS resolution for LB nodes
cat <<EOH >etc.hosts
$lb_1_ipv4 $lb_1_fqdn 
$lb_2_ipv4 $lb_2_fqdn 
EOH
_ssh -x "echo '$(<etc.hosts)' |sudo tee -a /etc/hosts"

# Install required software
_ssh -x sudo yum -y install keepalived haproxy psmisc 

# Upload required files 
printf "%s\n" $required_files |xargs -IX /bin/bash -c '_ssh -u $1 .' _ X

# Keepalived setup
## Each SLAVE node (hostname) must have unique "priority" value lower than MASTER.
_ssh -x "
    chmod +x check_apiserver.sh
    sudo cp -p check_apiserver.sh /etc/keepalived/
    sudo sed -i 's/VIP/$vip/'  /etc/keepalived/check_apiserver.sh
    sudo cp -p keepalived.conf /etc/keepalived/
    sudo sed -i 's/VIP/$vip/'  /etc/keepalived/keepalived.conf
    [[ \$(hostname) == $lb_2_fqdn ]] && {
        sudo sed -i 's/state MASTER/state SLAVE/'  /etc/keepalived/keepalived.conf
        sudo sed -i 's/priority 255/priority 254/' /etc/keepalived/keepalived.conf
    }
"

# HAProxy setup
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
## Show 'global secondary' route
_ssh -x ip -4 addr |grep $vip
## Verify connectivity
[[ $(type -t nc) ]] && nc -zv $vip 8443 || echo 'Use `nc -zv $vip 8443` to test connectivity'
## Verify HA dynamics
[[ $(type -t ping) ]] && {
    echo '
        While ping is running, use the hypervisor 
        to toggle off each control node (HA LB node).
        Connectivity should not be interrupted as long as 
        at least one such node is running.
    '
    ping -4 $vip 
} || echo 'Use `ping -4 $vip` to verify HA dynamics (power/toggle VMs).'