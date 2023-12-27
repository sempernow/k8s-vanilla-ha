#!/usr/bin/env bash
halb(){
    pushd ha-lb 

    lb_1_fqdn='a0.local'
    lb_2_fqdn='a1.local'
    device='eth0' # Applicable network interface device common to all LB nodes
    ## VIP must be static and not assignable by the DHCP server.
    vip='192.168.0.100' 
    vip6='::ffff:c0a8:64'

    target=keepalived-check_apiserver.sh
    cp ${target}.tpl $target
    sed -i "s/SET_VIP/$vip/" $target

   ## Generate a password common to all LB nodes
    pass="$(cat /proc/sys/kernel/random/uuid)" 
    
    target=keepalived.conf
    cp ${target}.tpl $target
    sed -i "s/SET_DEVICE/$device/" $target
    sed -i "s/SET_PASS/$pass/" $target
    sed -i "s/SET_VIP/$vip/" $target
    ## "priority VAL" of each SLAVE must be unique and lower than that of MASTER.
    cp $target keepalived-$lb_1_fqdn.sh
    cp $target keepalived-$lb_2_fqdn.sh
    rm $target
    target=keepalived-$lb_2_fqdn.sh
    sed -i "s/state MASTER/state SLAVE/"  $target
    sed -i "s/priority 255/priority 254/" $target

    ## Replace pattern "LB_?_FQDN LB_?_IPV4" with declared values.
    target=haproxy.cfg
    cp ${target}.tpl $target
    sed -i "s/LB_1_FQDN[[:space:]]LB_1_IPV4/$lb_1_fqdn $lb_1_ipv4/" $target
    sed -i "s/LB_2_FQDN[[:space:]]LB_2_IPV4/$lb_2_fqdn $lb_2_ipv4/" $target

    chmod +x *.sh

    ls -hlrtgG --time-style=long-iso

    popd
}

"$@"