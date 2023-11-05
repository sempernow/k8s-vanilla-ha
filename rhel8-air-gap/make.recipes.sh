#!/usr/bin/env bash
#################################################################
# See recipes of Makefile
#################################################################
vm_ip(){
    # Print IPv4 address of an ssh-configured Host ($1). 
    [[ $1 ]] || exit 99
    echo $(cat ~/.ssh/config |grep -A4 -B2 $1 |grep Hostname |head -n 1 |awk '{printf $2}')
}

halb(){
    #############################
    # DEPRICATED : See Makefile  
    #############################
    # Function halb generates the configuration for a 3-node 
    # Highly Available Load Balancer (HALB) built of HAProxy and Keepalived.
    # Configuration files, haproxy.cfg (LB) and keepalived-*.conf (HA; node failover),
    # are generated from their respective template file (*.tpl).
    [[ $HALB_VIP ]] || { echo "=== ENVIRONMENT is NOT CONFIGURED";exit 99; }
    pushd halb 
    # VIP must be static and not assignable by the subnet's DHCP server.
    vip="$HALB_VIP"
    # Set FQDN
    # Get/Set IP address of each LB node from ~/.ssh/config
    #echo "${HALB_FQDN_1%%.*}"
    #vm_ip ${HALB_FQDN_1%%.*}
    #exit
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

    # Generate a password common to all LB nodes
    pass="$(cat /proc/sys/kernel/random/uuid)" 
    
    target='keepalived.conf'
    cp ${target}.tpl $target
    sed -i "s/SET_DEVICE/$HALB_DEVICE/" $target
    sed -i "s/SET_PASS/$pass/" $target
    sed -i "s/SET_VIP/$HALB_VIP/" $target
    # Keepalived requires a unique configuration file 
    # (keepalived-*.conf) at each HAProxy-LB node on which it runs.
    # These *.conf files are identical except that "priority VAL" 
    # of each SLAVE must be unique and lower than that of MASTER.
    cp $target keepalived-$HALB_FQDN_1.conf
    cp $target keepalived-$HALB_FQDN_2.conf
    cp $target keepalived-$HALB_FQDN_3.conf
    rm $target

    target="keepalived-$HALB_FQDN_2.conf"
    sed -i "s/state MASTER/state SLAVE/"  $target
    sed -i "s/priority 255/priority 254/" $target

    target="keepalived-$HALB_FQDN_3.conf"
    sed -i "s/state MASTER/state SLAVE/"  $target
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

    # @ etc.hosts <=> /etc/hosts  ***  MUST PRESERVE TABs of HEREDOC  ***

	cat <<-EOH |tee etc.hosts
	127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
	::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
	$lb_1_ipv4 $HALB_FQDN_1
	$lb_2_ipv4 $HALB_FQDN_2
	$lb_3_ipv4 $HALB_FQDN_3
	EOH

    #ls -hlrtgG --time-style=long-iso

    popd
}

conf_kubectl(){
    # Configure client (kubectl) for GITOPS_USER on all nodes
    src='/etc/kubernetes/admin.conf'
    echo "=== Pull $src"
    [[ $K8S_INIT_NODE ]] || { echo '=== FAIL : K8S_INIT_NODE is UNSET'; return 0; }
    ssh ${GITOPS_USER}@$K8S_INIT_NODE 'sudo cp -p '"$src"' . && sudo chown $(id -u):$(id -g) admin.conf'
    scp ${GITOPS_USER}@$K8S_INIT_NODE:admin.conf .
    echo "=== Create \$HOME/.kube/config @ nodes: $ANSIBASH_TARGET_LIST"
    ansibash -u admin.conf config
    ansibash mkdir -p .kube
    ansibash cp -p config .kube/
}

"$@"