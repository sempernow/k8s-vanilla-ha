#!/usr/bin/env bash
#################################################################
# Generate all configuration files for a 3-node HALB;
# Highly Available (HA) Load Balancer (LB);
# built of HAProxy (LB) and Keepalived (HA/failover). 
#################################################################

vm_ip(){
    # Print IPv4 address of an ssh-configured Host ($1). 
    [[ $1 ]] || exit 99
    echo $(cat ~/.ssh/config |grep -A4 -B2 $1 |grep Hostname |head -n 1 |awk '{printf $2}')
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
lb_1_ipv4=$(vm_ip ${HALB_FQDN_1%%.*})
lb_2_ipv4=$(vm_ip ${HALB_FQDN_2%%.*})
lb_3_ipv4=$(vm_ip ${HALB_FQDN_3%%.*})
# Smoke test these gotten node-IP values : Abort on fail
[[ $lb_1_ipv4 ]] || { echo '=== FAIL @ lb_1_ipv4';exit 21; }
[[ $lb_2_ipv4 ]] || { echo '=== FAIL @ lb_2_ipv4';exit 22; }
[[ $lb_3_ipv4 ]] || { echo '=== FAIL @ lb_3_ipv4';exit 23; }

# @ keepalived

target='keepalived-check_apiserver.sh'
cp ${target}.tpl $target
sed -i "s/SET_VIP/$HALB_VIP/" $target
sed -i "s/SET_PORT_VIP/$HALB_PORT/" $target
sed -i "s/SET_PORT_UPSTREAM/6443/" $target
sed -i "s/SET_SCRIPT_FNAME/check_apiserver.sh/" $target

# Generate a password common to all LB nodes
#pass="$(cat /proc/sys/kernel/random/uuid)" 
pass="$(cat /dev/urandom |tr -dc [:alnum:] |fold -w8 |head -n1)" 

target='keepalived.conf'
cp ${target}.tpl $target
sed -i "s/SET_DEVICE/$HALB_DEVICE/" $target
sed -i "s/SET_PASS/$pass/" $target
sed -i "s/SET_VIP/$HALB_VIP/" $target
# Keepalived requires a unique configuration file 
# (keepalived-*.conf) at each HAProxy-LB node on which it runs.
# These *.conf files are identical except that "priority VAL" 
# of each BACKUP must be unique and lower than that of MASTER.
cp $target keepalived-$HALB_FQDN_1.conf
cp $target keepalived-$HALB_FQDN_2.conf
cp $target keepalived-$HALB_FQDN_3.conf
rm $target

target="keepalived-$HALB_FQDN_2.conf"
sed -i "s/state MASTER/state BACKUP/"  $target
sed -i "s/priority 255/priority 254/" $target

target="keepalived-$HALB_FQDN_3.conf"
sed -i "s/state MASTER/state BACKUP/"  $target
sed -i "s/priority 255/priority 253/" $target

# @ haproxy

# Replace pattern "LB_?_FQDN LB_?_IPV4" with declared values.
target='haproxy.cfg'
cp ${target}.tpl $target
sed -i "s/LB_1_FQDN[[:space:]]LB_1_IPV4/$HALB_FQDN_1 $lb_1_ipv4/" $target
sed -i "s/LB_2_FQDN[[:space:]]LB_2_IPV4/$HALB_FQDN_2 $lb_2_ipv4/" $target
sed -i "s/LB_3_FQDN[[:space:]]LB_3_IPV4/$HALB_FQDN_3 $lb_3_ipv4/" $target
sed -i "s/LB_PORT/$HALB_PORT/" $target
sed -i "s/LB_DEVICE/$HALB_DEVICE/" $target

# @ etc.hosts <=> /etc/hosts

cat <<-EOH |tee etc.hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
$lb_1_ipv4 $HALB_FQDN_1
$lb_2_ipv4 $HALB_FQDN_2
$lb_3_ipv4 $HALB_FQDN_3
EOH

# @ /etc/environment : Reset no_proxy param

target='etc.environment'
no_proxy="$(cat /etc/environment |grep -i no_proxy |cut -d'=' -f2)"
halb_addr_list="
    $HALB_CIDR
    .$HALB_FQDN_1 
    .$HALB_FQDN_2 
    .$HALB_FQDN_3
"
# Append HALB addresses to those already in no_proxy
for addr in $halb_addr_list; do no_proxy=$no_proxy,$addr;done
# Capture source file, deleting its "no_proxy=..." line
sed  "/no_proxy/d" /etc/environment >$target
# Append the new no_proxy line
echo "no_proxy=$no_proxy" |tee -a $target

popd